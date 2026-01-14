import json
from pprint import pformat, pprint
from os import path as osp, remove
from textwrap import dedent

import boto3
import pytest
import requests
from pytest_infrahouse import terraform_apply
from pytest_infrahouse.utils import wait_for_instance_refresh

from tests.conftest import (
    LOG,
    TEST_TIMEOUT,
    UBUNTU_CODENAME,
)


@pytest.mark.timeout(TEST_TIMEOUT)
@pytest.mark.parametrize(
    "lb_subnets,expected_scheme",
    [("subnet_public_ids", "internet-facing"), ("subnet_private_ids", "internal")],
)
@pytest.mark.parametrize(
    "aws_provider_version", ["~> 5.31", "~> 6.0"], ids=["aws-5", "aws-6"]
)
def test_lb(
    service_network,
    boto3_session,
    lb_subnets,
    expected_scheme,
    aws_provider_version,
    keep_after,
    aws_region,
    test_role_arn,
    subzone,
):
    # Create AWS clients from session
    ec2_client = boto3_session.client("ec2", region_name=aws_region)
    route53_client = boto3_session.client("route53", region_name=aws_region)
    elbv2_client = boto3_session.client("elbv2", region_name=aws_region)
    autoscaling_client = boto3_session.client("autoscaling", region_name=aws_region)

    subnet_private_ids = service_network["subnet_private_ids"]["value"]
    internet_gateway_id = service_network["internet_gateway_id"]["value"]
    lb_subnet_ids = service_network[lb_subnets]["value"]
    zone_id = subzone["subzone_id"]["value"]

    terraform_dir = "test_data/test_create_lb"

    # Clean up any existing Terraform state to ensure clean test
    import shutil

    state_files = [
        osp.join(terraform_dir, ".terraform"),
        osp.join(terraform_dir, ".terraform.lock.hcl"),
    ]

    for state_file in state_files:
        try:
            if osp.isdir(state_file):
                shutil.rmtree(state_file)
            elif osp.isfile(state_file):
                remove(state_file)
        except FileNotFoundError:
            # File was already removed by another process
            pass

    # Update terraform.tf with the specified AWS provider version
    terraform_tf_content = dedent(
        f"""
        terraform {{
          required_providers {{
            aws = {{
              source  = "hashicorp/aws"
              version = "{aws_provider_version}"
            }}
          }}
        }}
        """
    )

    with open(osp.join(terraform_dir, "terraform.tf"), "w") as fp:
        fp.write(terraform_tf_content)

    instance_name = "foo-app"
    alarm_emails = ["devnull@infrahouse.com"]
    with open(osp.join(terraform_dir, "terraform.tfvars"), "w") as fp:
        fp.write(
            dedent(
                f"""
                region          = "{aws_region}"
                zone_id         = "{zone_id}"
                ubuntu_codename = "{UBUNTU_CODENAME}"
                alarm_emails = {json.dumps(alarm_emails)}
                tags = {{
                    Name: "{instance_name}"
                }}

                lb_subnet_ids       = {json.dumps(lb_subnet_ids)}
                backend_subnet_ids  = {json.dumps(subnet_private_ids)}
                internet_gateway_id = "{internet_gateway_id}"
                """
            )
        )
        if test_role_arn:
            fp.write(
                dedent(
                    f"""
                    role_arn      = "{test_role_arn}"
                    """
                )
            )

    with terraform_apply(
        terraform_dir,
        destroy_after=not keep_after,
        json_output=True,
    ) as tf_output:
        print(json.dumps(tf_output, indent=4))

        # Get the full zone name from terraform output (e.g., abcd.ci-cd.infrahouse.com)
        test_zone_name = tf_output["test_zone_name"]["value"]

        LOG.info("=" * 80)
        LOG.info("Verifying DNS configuration")
        LOG.info("=" * 80)

        response = route53_client.list_hosted_zones_by_name(DNSName=test_zone_name)
        assert len(response["HostedZones"]) > 0, "Zone %s is not hosted by AWS: %s" % (
            test_zone_name,
            response,
        )
        zone_id = response["HostedZones"][0]["Id"]
        LOG.info("✓ Hosted zone exists: %s", test_zone_name)

        response = route53_client.list_resource_record_sets(HostedZoneId=zone_id)
        LOG.debug("list_resource_record_sets() = %s", pformat(response, indent=4))

        records = [
            a["Name"]
            for a in response["ResourceRecordSets"]
            if a["Type"] in ["A", "CAA"]
        ]
        assert f"{test_zone_name}." in records, "Record %s is missing in %s: %s" % (
            test_zone_name,
            test_zone_name,
            pformat(records, indent=4),
        )

        for record in ["bogus-test-stuff", "www"]:
            assert (
                "%s.%s." % (record, test_zone_name) in records
            ), "Record %s is missing in %s: %s" % (
                record,
                test_zone_name,
                pformat(records, indent=4),
            )
        LOG.info(
            "✓ DNS records verified: %s, bogus-test-stuff.%s, www.%s",
            test_zone_name,
            test_zone_name,
            test_zone_name,
        )

        LOG.info("=" * 80)
        LOG.info("Verifying VPC configuration")
        LOG.info("=" * 80)

        response = ec2_client.describe_vpcs(
            Filters=[
                {"Name": "cidr", "Values": ["10.1.0.0/16"]},
                {"Name": "vpc-id", "Values": [service_network["vpc_id"]["value"]]},
            ],
        )
        assert len(response["Vpcs"]) == 1, "Unexpected number of VPC: %s" % pformat(
            response, indent=4
        )
        LOG.info("✓ VPC verified: %s (10.1.0.0/16)", service_network["vpc_id"]["value"])

        LOG.info("=" * 80)
        LOG.info("Verifying Load Balancer configuration")
        LOG.info("=" * 80)

        response = elbv2_client.describe_load_balancers()
        LOG.debug("describe_load_balancers(): %s", pformat(response, indent=4))

        # Filter load balancers by VPC ID
        vpc_load_balancers = [
            lb
            for lb in response["LoadBalancers"]
            if lb["VpcId"] == service_network["vpc_id"]["value"]
        ]

        assert (
            len(vpc_load_balancers) == 1
        ), "Unexpected number of Load Balancer in VPC: %s" % pformat(
            vpc_load_balancers, indent=4
        )

        assert vpc_load_balancers[0]["Scheme"] == expected_scheme
        assert len(vpc_load_balancers[0]["AvailabilityZones"]) == len(
            lb_subnet_ids
        ), "Unexpected number of Availability Zones: %s" % pformat(
            vpc_load_balancers, indent=4
        )
        LOG.info(
            "✓ Load balancer verified: scheme=%s, AZs=%d",
            expected_scheme,
            len(vpc_load_balancers[0]["AvailabilityZones"]),
        )

        lb_arn = vpc_load_balancers[0]["LoadBalancerArn"]
        response = elbv2_client.describe_listeners(
            LoadBalancerArn=lb_arn,
        )
        LOG.debug("describe_listeners(%s): %s", lb_arn, pformat(response, indent=4))
        assert (
            len(response["Listeners"]) == 2
        ), "Unexpected number of listeners: %s" % pformat(response, indent=4)
        LOG.info(
            "✓ Listeners verified: %d listeners configured", len(response["Listeners"])
        )

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
        LOG.info("✓ Target health verified: %d healthy targets", healthy_count)

        if expected_scheme == "internet-facing":
            LOG.info("=" * 80)
            LOG.info("Verifying HTTP/HTTPS endpoints")
            LOG.info("=" * 80)

            for a_rec in ["bogus-test-stuff", "www"]:
                response = requests.get("https://%s.%s" % (a_rec, test_zone_name))
                assert all(
                    (
                        response.status_code == 200,
                        response.text == "Success Message\r\n",
                    )
                ), (
                    "Unsuccessful HTTP response: %s" % response.text
                )
            LOG.info(
                "✓ HTTPS endpoints responding correctly: bogus-test-stuff.%s, www.%s",
                test_zone_name,
                test_zone_name,
            )

            response = requests.get(
                f"https://{tf_output['load_balancer_dns_name']['value']}", verify=False
            )
            assert response.status_code == 400
            LOG.info("✓ Direct ALB access returns 400 (expected)")

        LOG.info("=" * 80)
        LOG.info("Verifying AutoScaling Group configuration")
        LOG.info("=" * 80)

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
        LOG.info("✓ Instance tags verified: Name=%s", instance_name)

        # Verify Vanta compliance CloudWatch alarms
        LOG.info("=" * 80)
        LOG.info("Verifying CloudWatch alarms for Vanta compliance")
        LOG.info("=" * 80)

        cw_client = boto3_session.client("cloudwatch", region_name=aws_region)
        sns_client = boto3_session.client("sns", region_name=aws_region)

        # 1. Verify SNS topic created
        topic_arn = tf_output["alarm_sns_topic_arn"]["value"]
        LOG.info("Verifying SNS topic: %s", topic_arn)
        assert (
            topic_arn is not None
        ), "SNS topic should be created when alarm_emails is configured"

        # 2. Verify email subscription exists (PendingConfirmation is acceptable)
        subs = sns_client.list_subscriptions_by_topic(TopicArn=topic_arn)
        LOG.debug("SNS subscriptions: %s", pformat(subs, indent=4))
        email_subs = [s for s in subs["Subscriptions"] if s["Protocol"] == "email"]
        assert (
            len(email_subs) == 1
        ), f"Expected 1 email subscription, found {len(email_subs)}"
        assert (
            email_subs[0]["Endpoint"] == alarm_emails[0]
        ), f"Email subscription endpoint mismatch: {email_subs[0]['Endpoint']} != {alarm_emails[0]}"
        LOG.info("✓ SNS topic and email subscription verified")

        # 3. Verify all 4 alarms exist
        alarm_arns = tf_output["cloudwatch_alarm_arns"]["value"]
        assert (
            alarm_arns["unhealthy_hosts"] is not None
        ), "Unhealthy hosts alarm should exist"
        assert alarm_arns["high_latency"] is not None, "High latency alarm should exist"
        assert (
            alarm_arns["low_success_rate"] is not None
        ), "Low success rate alarm should exist"
        assert alarm_arns["high_cpu"] is not None, "High CPU alarm should exist"
        LOG.info("✓ All 4 CloudWatch alarms exist")

        # 4. Get alarm details and verify configurations
        alarm_names = [arn.split(":")[-1] for arn in alarm_arns.values()]
        alarms_response = cw_client.describe_alarms(AlarmNames=alarm_names)
        LOG.debug("CloudWatch alarms: %s", pformat(alarms_response, indent=4))
        alarms = {a["AlarmName"]: a for a in alarms_response["MetricAlarms"]}

        # 5. Verify CPU alarm configuration
        cpu_alarm = [a for a in alarms.values() if "high-cpu" in a["AlarmName"]][0]
        assert (
            cpu_alarm["Threshold"] == 90
        ), f"CPU threshold should be 90% (60% + 30%), got {cpu_alarm['Threshold']}"
        assert (
            cpu_alarm["Period"] == 300
        ), f"CPU alarm period should be 5 minutes (300s), got {cpu_alarm['Period']}"
        assert (
            cpu_alarm["EvaluationPeriods"] == 2
        ), f"CPU alarm evaluation periods should be 2, got {cpu_alarm['EvaluationPeriods']}"
        assert (
            cpu_alarm["Dimensions"][0]["Name"] == "AutoScalingGroupName"
        ), f"CPU alarm should monitor AutoScalingGroupName dimension, got {cpu_alarm['Dimensions'][0]['Name']}"
        assert (
            cpu_alarm["Dimensions"][0]["Value"] == asg_name
        ), f"CPU alarm should monitor ASG {asg_name}, got {cpu_alarm['Dimensions'][0]['Value']}"
        assert (
            topic_arn in cpu_alarm["AlarmActions"]
        ), "CPU alarm should send to SNS topic"
        LOG.info("✓ CPU alarm configuration verified")

        # 6. Verify unhealthy host alarm
        unhealthy_alarm = [
            a for a in alarms.values() if "unhealthy-hosts" in a["AlarmName"]
        ][0]
        assert (
            unhealthy_alarm["Threshold"] == 1
        ), f"Unhealthy hosts threshold should be 1, got {unhealthy_alarm['Threshold']}"
        assert (
            unhealthy_alarm["Period"] == 60
        ), f"Unhealthy hosts period should be 60s, got {unhealthy_alarm['Period']}"
        assert (
            unhealthy_alarm["EvaluationPeriods"] == 2
        ), f"Unhealthy hosts evaluation periods should be 2, got {unhealthy_alarm['EvaluationPeriods']}"
        assert (
            topic_arn in unhealthy_alarm["AlarmActions"]
        ), "Unhealthy hosts alarm should send to SNS topic"
        LOG.info("✓ Unhealthy hosts alarm configuration verified")

        # 7. Verify latency alarm
        latency_alarm = [
            a for a in alarms.values() if "high-latency" in a["AlarmName"]
        ][0]
        assert (
            latency_alarm["Threshold"] == 48
        ), f"Latency threshold should be 48s (80% of 60s idle timeout), got {latency_alarm['Threshold']}"
        assert (
            latency_alarm["Period"] == 60
        ), f"Latency alarm period should be 60s, got {latency_alarm['Period']}"
        assert (
            topic_arn in latency_alarm["AlarmActions"]
        ), "Latency alarm should send to SNS topic"
        LOG.info("✓ Latency alarm configuration verified")

        # 8. Verify success rate alarm (uses metric math)
        success_alarm = [
            a for a in alarms.values() if "low-success-rate" in a["AlarmName"]
        ][0]
        assert (
            success_alarm["Threshold"] == 99.0
        ), f"Success rate threshold should be 99.0%, got {success_alarm['Threshold']}"
        assert (
            "Metrics" in success_alarm
        ), "Success rate alarm should use metric math (Metrics field)"
        assert (
            topic_arn in success_alarm["AlarmActions"]
        ), "Success rate alarm should send to SNS topic"
        LOG.info("✓ Success rate alarm configuration verified")

        LOG.info("=" * 80)
        LOG.info("All Vanta compliance CloudWatch alarms verified successfully!")
        LOG.info("=" * 80)

    if not keep_after:
        response = ec2_client.describe_volumes(
            Filters=[{"Name": "status", "Values": ["available"]}],
        )
        assert (
            len(response["Volumes"]) == 0
        ), "Unexpected number of EBS volumes: %s" % pformat(response, indent=4)
