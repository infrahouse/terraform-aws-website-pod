import json
from os import path as osp
from pprint import pformat
from textwrap import dedent

import pytest
from infrahouse_toolkit.terraform import terraform_apply

from tests.conftest import (
    LOG,
    TEST_ZONE,
    REGION,
    UBUNTU_CODENAME,
    TRACE_TERRAFORM,
    DESTROY_AFTER,
    TERRAFORM_ROOT_DIR,
    TEST_ROLE_ARN,
    TEST_TIMEOUT,
    wait_for_instance_refresh,
)


@pytest.mark.timeout(TEST_TIMEOUT)
def test_lb(
    service_network,
    instance_profile,
    ec2_client,
    route53_client,
    elbv2_client,
    autoscaling_client,
):
    subnet_public_ids = service_network["subnet_public_ids"]["value"]
    subnet_private_ids = service_network["subnet_private_ids"]["value"]
    internet_gateway_id = service_network["internet_gateway_id"]["value"]

    terraform_dir = osp.join(TERRAFORM_ROOT_DIR, "test_create_lb")
    with open(osp.join(terraform_dir, "terraform.tfvars"), "w") as fp:
        fp.write(
            dedent(
                f"""
                region                = "{REGION}"
                role_arn              = "{TEST_ROLE_ARN}"
                dns_zone              = "{TEST_ZONE}"
                instance_profile_name = "{instance_profile['instance_profile_name']['value']}"
                ubuntu_codename       = "{UBUNTU_CODENAME}"
                tags = {{
                    Name: "foo-app"
                }}

                lb_subnet_ids = {json.dumps(subnet_public_ids)}
                backend_subnet_ids = {json.dumps(subnet_private_ids)}
                internet_gateway_id = "{internet_gateway_id}"
                """
            )
        )

    with terraform_apply(
        terraform_dir,
        destroy_after=DESTROY_AFTER,
        json_output=True,
        enable_trace=TRACE_TERRAFORM,
    ) as tf_output:
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

        for instance in response["AutoScalingGroups"][0]["Instances"]:
            LOG.debug("Evaluating instance %s", pformat(instance, indent=4))
            di_response = ec2_client.describe_instances(
                InstanceIds=[instance["InstanceId"]]
            )
            LOG.debug(
                "describe_instances(%s) = %s",
                instance["InstanceId"],
                pformat(di_response, indent=4),
            )

            assert (
                di_response["Reservations"][0]["Instances"][0]["IamInstanceProfile"][
                    "Arn"
                ]
                == instance_profile["instance_profile_arn"]["value"]
            )
