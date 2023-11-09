import json
from pprint import pformat
from os import path as osp
from textwrap import dedent
from time import sleep

import pytest
import requests
from infrahouse_toolkit.terraform import terraform_apply

from tests.conftest import (
    LOG,
    TEST_ZONE,
    REGION,
    UBUNTU_CODENAME,
    TRACE_TERRAFORM,
    DESTROY_AFTER,
)


@pytest.mark.flaky(reruns=0, reruns_delay=30)
@pytest.mark.timeout(1800)
def test_lb(ec2_client, route53_client, elbv2_client, autoscaling_client):
    terraform_dir = "test_data/test_create_lb"

    instance_name = "foo-app"
    with open(osp.join(terraform_dir, "terraform.tfvars"), "w") as fp:
        fp.write(
            dedent(
                f"""
                region = "{REGION}"
                dns_zone = "{TEST_ZONE}"
                ubuntu_codename = "{UBUNTU_CODENAME}"
                tags = {{
                    Name: "{instance_name}"
                }}
                """
            )
        )

    with terraform_apply(
        terraform_dir,
        destroy_after=DESTROY_AFTER,
        json_output=True,
        enable_trace=TRACE_TERRAFORM,
    ) as tf_output:
        assert len(tf_output["network_subnet_private_ids"]) == 3
        assert len(tf_output["network_subnet_public_ids"]) == 3

        response = route53_client.list_hosted_zones_by_name(DNSName=TEST_ZONE)
        assert len(response["HostedZones"]) == 1, "Zone %s is not hosted by AWS: %s" % (
            TEST_ZONE,
            response,
        )
        zone_id = response["HostedZones"][0]["Id"]

        response = route53_client.list_resource_record_sets(HostedZoneId=zone_id)
        a_records = [
            a["Name"] for a in response["ResourceRecordSets"] if a["Type"] == "A"
        ]
        for record in ["bogus-test-stuff", "www"]:
            assert (
                "%s.%s." % (record, TEST_ZONE) in a_records
            ), "Record %s is missing in %s: %s" % (
                record,
                TEST_ZONE,
                pformat(a_records, indent=4),
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

        tg_arn = listener["DefaultActions"][0]["TargetGroupArn"]
        response = elbv2_client.describe_target_health(TargetGroupArn=tg_arn)
        LOG.debug("describe_target_health(%s): %s", tg_arn, pformat(response, indent=4))
        healthy_count = 0
        for thd in response["TargetHealthDescriptions"]:
            if thd["TargetHealth"]["State"] == "healthy":
                healthy_count += 1
        assert healthy_count == 3

        for a_rec in ["bogus-test-stuff", "www"]:
            response = requests.get("https://%s.%s" % (a_rec, TEST_ZONE))
            assert all(
                (response.status_code == 200, response.text == "Success Message\r\n")
            ), ("Unsuccessful HTTP response: %s" % response.text)

        # Check tags on ASG instances
        asg_name = tf_output["asg_name"]["value"]
        # Wait for any instance refreshes to finish
        while True:
            response = autoscaling_client.describe_instance_refreshes(
                AutoScalingGroupName=asg_name
            )
            LOG.debug(
                "describe_instance_refreshes(%s): %s",
                asg_name,
                pformat(response, indent=4),
            )
            current_refreshes = 0
            for refresh in response["InstanceRefreshes"]:
                if refresh["Status"] in [
                    "Pending",
                    "InProgress",
                    "Cancelling",
                    "RollbackInProgress",
                ]:
                    current_refreshes += 1

            if current_refreshes > 0:
                LOG.info("Waiting until %s finishes the instance refreshes", asg_name)
                sleep(5)
                continue

            break

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

    response = ec2_client.describe_volumes(
        Filters=[{"Name": "status", "Values": ["available"]}],
    )
    assert (
        len(response["Volumes"]) == 0
    ), "Unexpected number of EBS volumes: %s" % pformat(response, indent=4)
