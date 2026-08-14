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
                region             = "{aws_region}"
                zone_id            = "{zone_id}"
                ubuntu_codename    = "{UBUNTU_CODENAME}"
                asg_name           = "foo-asg"
                instance_role_name = "foo-role"
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

        # EBS encryption (issue #124), checked at two levels:
        # 1. The launch template must request encryption, so the module does not
        #    rely on the account's "EBS encryption by default" setting.
        # 2. The volumes actually created for the ASG instances must be encrypted.
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
        ), f"launch template does not request EBS encryption: {ebs_mappings}"

        instance_ids = [instance["InstanceId"] for instance in asg["Instances"]]
        assert instance_ids, "ASG foo-asg has no instances"

        volumes = ec2_client.describe_volumes(
            Filters=[
                {"Name": "attachment.instance-id", "Values": instance_ids},
            ]
        )["Volumes"]
        assert volumes, f"no EBS volumes attached to ASG instances {instance_ids}"
        unencrypted = [
            volume["VolumeId"] for volume in volumes if not volume["Encrypted"]
        ]
        assert not unencrypted, f"unencrypted EBS volumes: {unencrypted}"

        # The instances must run with the module-created instance profile
        # (asg.tf iam_instance_profile wiring) carrying the requested role.
        instance_profile_name = tf_output["instance_profile_name"]["value"]
        instances = [
            instance
            for reservation in ec2_client.describe_instances(InstanceIds=instance_ids)[
                "Reservations"
            ]
            for instance in reservation["Instances"]
        ]
        for instance in instances:
            profile_arn = instance.get("IamInstanceProfile", {}).get("Arn")
            assert profile_arn and profile_arn.endswith(
                f"/{instance_profile_name}"
            ), f"instance {instance['InstanceId']} runs with profile {profile_arn}, expected {instance_profile_name}"

        iam_client = boto3_session.client("iam")
        roles = iam_client.get_instance_profile(
            InstanceProfileName=instance_profile_name
        )["InstanceProfile"]["Roles"]
        assert [role["RoleName"] for role in roles] == [
            "foo-role"
        ], f"unexpected roles in {instance_profile_name}: {roles}"
