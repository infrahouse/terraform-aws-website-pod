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
    TERRAFORM_ROOT_DIR,
    TEST_ROLE_ARN,
    TEST_TIMEOUT,
    wait_for_instance_refresh,
)


@pytest.mark.timeout(TEST_TIMEOUT)
def test_lb(
    service_network,
    ec2_client,
    route53_client,
    elbv2_client,
    autoscaling_client,
    iam_client,
    keep_after,
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
                ubuntu_codename       = "{UBUNTU_CODENAME}"
                tags = {{
                    Name: "foo-app"
                }}

                lb_subnet_ids       = {json.dumps(subnet_public_ids)}
                backend_subnet_ids  = {json.dumps(subnet_private_ids)}
                internet_gateway_id = "{internet_gateway_id}"
                instance_role_name  = "foo-role"
                """
            )
        )

    with terraform_apply(
        terraform_dir,
        destroy_after=not keep_after,
        json_output=True,
        enable_trace=TRACE_TERRAFORM,
    ) as tf_output:
        asg_name = tf_output["asg_name"]["value"]
        wait_for_instance_refresh(asg_name, autoscaling_client)

        instance_profile_name = tf_output["instance_profile_name"]["value"]
        response = iam_client.get_instance_profile(
            InstanceProfileName=instance_profile_name
        )
        LOG.debug(
            "get_instance_profile(%s): %s",
            instance_profile_name,
            pformat(response, indent=4),
        )
        assert response["InstanceProfile"]["Roles"][0]["RoleName"] == "foo-role"
