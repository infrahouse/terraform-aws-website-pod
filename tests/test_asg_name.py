import json
from os import path as osp
from textwrap import dedent

import pytest
from pytest_infrahouse import terraform_apply

from tests.conftest import (
    UBUNTU_CODENAME,
    TEST_TIMEOUT,
)


@pytest.mark.timeout(TEST_TIMEOUT)
def test_lb(
    service_network,
    keep_after,
    aws_region,
    test_role_arn,
    subzone,
    boto3_session,
):
    subnet_public_ids = service_network["subnet_public_ids"]["value"]
    subnet_private_ids = service_network["subnet_private_ids"]["value"]
    zone_id = subzone["subzone_id"]["value"]

    terraform_dir = "test_data/test_create_lb"

    instance_name = "foo-app"
    with open(osp.join(terraform_dir, "terraform.tfvars"), "w") as fp:
        fp.write(dedent(f"""
                region          = "{aws_region}"
                zone_id         = "{zone_id}"
                ubuntu_codename = "{UBUNTU_CODENAME}"
                asg_name        = "foo-asg"
                tags = {{
                    Name: "{instance_name}"
                }}

                lb_subnet_ids = {json.dumps(subnet_public_ids)}
                backend_subnet_ids = {json.dumps(subnet_private_ids)}
                replication_region = "{"us-east-2" if aws_region == "us-east-1" else "us-east-1"}"
                """))
        if test_role_arn:
            fp.write(dedent(f"""
                    role_arn      = "{test_role_arn}"
                    """))

    with terraform_apply(
        terraform_dir,
        destroy_after=not keep_after,
        json_output=True,
    ) as tf_output:
        assert tf_output["asg_name"]["value"] == "foo-asg"

        # The launch template must encrypt the root EBS volume regardless of the
        # account's "EBS encryption by default" setting (issue #124).
        autoscaling_client = boto3_session.client("autoscaling", region_name=aws_region)
        ec2_client = boto3_session.client("ec2", region_name=aws_region)

        asg = autoscaling_client.describe_auto_scaling_groups(
            AutoScalingGroupNames=["foo-asg"],
        )["AutoScalingGroups"][0]
        launch_template = (
            asg.get("LaunchTemplate")
            or asg["MixedInstancesPolicy"]["LaunchTemplate"][
                "LaunchTemplateSpecification"
            ]
        )
        template_data = ec2_client.describe_launch_template_versions(
            LaunchTemplateId=launch_template["LaunchTemplateId"],
            Versions=[launch_template["Version"]],
        )["LaunchTemplateVersions"][0]["LaunchTemplateData"]

        ebs_mappings = [
            m["Ebs"] for m in template_data["BlockDeviceMappings"] if "Ebs" in m
        ]
        assert ebs_mappings, "launch template has no EBS block device mappings"
        assert all(
            mapping["Encrypted"] for mapping in ebs_mappings
        ), f"root EBS volume is not encrypted: {ebs_mappings}"
