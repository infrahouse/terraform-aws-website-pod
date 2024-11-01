import json
from pprint import pformat
from os import path as osp
from textwrap import dedent

import pytest
import requests
from infrahouse_toolkit.terraform import terraform_apply

from tests.conftest import (
    LOG,
    TEST_ZONE,
    REGION,
    UBUNTU_CODENAME,
    TRACE_TERRAFORM,
    TEST_ROLE_ARN,
    TEST_TIMEOUT,
    wait_for_instance_refresh,
)


@pytest.mark.timeout(TEST_TIMEOUT)
@pytest.mark.parametrize(
    "lb_subnets,expected_scheme",
    [("subnet_public_ids", "internet-facing"), ("subnet_private_ids", "internal")],
)
def test_lb(
    service_network,
    ec2_client,
    route53_client,
    elbv2_client,
    autoscaling_client,
    lb_subnets,
    expected_scheme,
    keep_after,
):
    subnet_private_ids = service_network["subnet_private_ids"]["value"]
    internet_gateway_id = service_network["internet_gateway_id"]["value"]
    lb_subnet_ids = service_network[lb_subnets]["value"]

    terraform_dir = "test_data/test_create_lb"

    instance_name = "foo-app"
    with open(osp.join(terraform_dir, "terraform.tfvars"), "w") as fp:
        fp.write(
            dedent(
                f"""
                region          = "{REGION}"
                dns_zone        = "{TEST_ZONE}"
                ubuntu_codename = "{UBUNTU_CODENAME}"
                role_arn        = "{TEST_ROLE_ARN}"
                tags = {{
                    Name: "{instance_name}"
                }}

                lb_subnet_ids       = {json.dumps(lb_subnet_ids)}
                backend_subnet_ids  = {json.dumps(subnet_private_ids)}
                internet_gateway_id = "{internet_gateway_id}"
                """
            )
        )

    with terraform_apply(
        terraform_dir,
        destroy_after=not keep_after,
        json_output=True,
        enable_trace=TRACE_TERRAFORM,
    ) as tf_output:
        assert len(tf_output["network_subnet_private_ids"]) == 3
        assert len(tf_output["network_subnet_public_ids"]) == 3

        response = route53_client.list_hosted_zones_by_name(DNSName=TEST_ZONE)
        assert len(response["HostedZones"]) > 0, "Zone %s is not hosted by AWS: %s" % (
            TEST_ZONE,
            response,
        )
        zone_id = response["HostedZones"][0]["Id"]

        response = route53_client.list_resource_record_sets(HostedZoneId=zone_id)
        LOG.debug("list_resource_record_sets() = %s", pformat(response, indent=4))

        records = [
            a["Name"]
            for a in response["ResourceRecordSets"]
            if a["Type"] in ["CNAME", "A"]
        ]
        assert f"{TEST_ZONE}." in records, "Record %s is missing in %s: %s" % (
            TEST_ZONE,
            TEST_ZONE,
            pformat(records, indent=4),
        )

        for record in ["bogus-test-stuff", "www"]:
            assert (
                "%s.%s." % (record, TEST_ZONE) in records
            ), "Record %s is missing in %s: %s" % (
                record,
                TEST_ZONE,
                pformat(records, indent=4),
            )

        response = ec2_client.describe_vpcs(
            Filters=[{"Name": "cidr", "Values": ["10.1.0.0/16"]}],
        )
        # Check VPC is created
        assert len(response["Vpcs"]) == 1, "Unexpected number of VPC: %s" % pformat(
            response, indent=4
        )

        response = elbv2_client.describe_load_balancers()
        LOG.debug("describe_load_balancers(): %s", pformat(response, indent=4))
        assert (
            len(response["LoadBalancers"]) == 1
        ), "Unexpected number of Load Balancer: %s" % pformat(response, indent=4)

        assert response["LoadBalancers"][0]["Scheme"] == expected_scheme
        assert (
            len(response["LoadBalancers"][0]["AvailabilityZones"]) == 3
        ), "Unexpected number of Availability Zones: %s" % pformat(response, indent=4)

        lb_arn = response["LoadBalancers"][0]["LoadBalancerArn"]
        response = elbv2_client.describe_listeners(
            LoadBalancerArn=lb_arn,
        )
        LOG.debug("describe_listeners(%s): %s", lb_arn, pformat(response, indent=4))
        assert (
            len(response["Listeners"]) == 2
        ), "Unexpected number of listeners: %s" % pformat(response, indent=4)

        ssl_listeners = [
            listener for listener in response["Listeners"] if listener["Port"] == 443
        ]
        listener = ssl_listeners[0]
        response = elbv2_client.describe_rules(
            ListenerArn=listener["ListenerArn"],
        )
        LOG.debug(
            "describe_rules(%s): %s",
            listener["ListenerArn"],
            pformat(response, indent=4),
        )
        forward_rules = [
            rule
            for rule in response["Rules"]
            if rule["Actions"][0]["Type"] == "forward"
        ]

        tg_arn = forward_rules[0]["Actions"][0]["TargetGroupArn"]
        response = elbv2_client.describe_target_health(TargetGroupArn=tg_arn)
        LOG.debug("describe_target_health(%s): %s", tg_arn, pformat(response, indent=4))
        healthy_count = 0
        for thd in response["TargetHealthDescriptions"]:
            if thd["TargetHealth"]["State"] == "healthy":
                healthy_count += 1
        assert healthy_count == 3

        if expected_scheme == "internet-facing":
            for a_rec in ["bogus-test-stuff", "www"]:
                response = requests.get("https://%s.%s" % (a_rec, TEST_ZONE))
                assert all(
                    (
                        response.status_code == 200,
                        response.text == "Success Message\r\n",
                    )
                ), (
                    "Unsuccessful HTTP response: %s" % response.text
                )
            response = requests.get(
                f"https://{tf_output['load_balancer_dns_name']['value']}", verify=False
            )
            assert response.status_code == 400

        # Check tags on ASG instances
        asg_name = tf_output["asg_name"]["value"]
        wait_for_instance_refresh(asg_name, autoscaling_client)

        response = autoscaling_client.describe_auto_scaling_groups(
            AutoScalingGroupNames=[
                asg_name,
            ],
        )
        LOG.debug(
            "describe_auto_scaling_groups(%s): %s",
            asg_name,
            pformat(response, indent=4),
        )

        healthy_instance = None
        for instance in response["AutoScalingGroups"][0]["Instances"]:
            LOG.debug("Evaluating instance %s", pformat(instance, indent=4))
            if instance["LifecycleState"] == "InService":
                healthy_instance = instance
                break
        assert healthy_instance, f"Could not find a healthy instance in ASG {asg_name}"
        response = ec2_client.describe_tags(
            Filters=[
                {
                    "Name": "resource-id",
                    "Values": [
                        healthy_instance["InstanceId"],
                    ],
                },
            ],
        )
        LOG.debug(
            "describe_tags(%s): %s",
            healthy_instance["InstanceId"],
            pformat(response, indent=4),
        )
        tags = {}
        for tag in response["Tags"]:
            tags[tag["Key"]] = tag["Value"]

        assert (
            tags["Name"] == instance_name
        ), f"Instance's name should be set to {instance_name}."

    if not keep_after:
        response = ec2_client.describe_volumes(
            Filters=[{"Name": "status", "Values": ["available"]}],
        )
        assert (
            len(response["Volumes"]) == 0
        ), "Unexpected number of EBS volumes: %s" % pformat(response, indent=4)
