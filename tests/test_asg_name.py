import json
from os import path as osp
from textwrap import dedent

import pytest
from infrahouse_toolkit.terraform import terraform_apply

from tests.conftest import (
    TEST_ZONE,
    REGION,
    UBUNTU_CODENAME,
    TRACE_TERRAFORM,
    TEST_ROLE_ARN,
    TEST_TIMEOUT,
)


@pytest.mark.timeout(TEST_TIMEOUT)
def test_lb(
    service_network,
    ec2_client,
    route53_client,
    elbv2_client,
    autoscaling_client,
    keep_after,
):
    subnet_public_ids = service_network["subnet_public_ids"]["value"]
    subnet_private_ids = service_network["subnet_private_ids"]["value"]
    internet_gateway_id = service_network["internet_gateway_id"]["value"]

    terraform_dir = "test_data/test_create_lb"

    instance_name = "foo-app"
    with open(osp.join(terraform_dir, "terraform.tfvars"), "w") as fp:
        fp.write(
            dedent(
                f"""
                region          = "{REGION}"
                role_arn        = "{TEST_ROLE_ARN}"
                dns_zone        = "{TEST_ZONE}"
                ubuntu_codename = "{UBUNTU_CODENAME}"
                asg_name        = "foo-asg"
                tags = {{
                    Name: "{instance_name}"
                }}

                lb_subnet_ids = {json.dumps(subnet_public_ids)}
                backend_subnet_ids = {json.dumps(subnet_private_ids)}
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
        assert tf_output["asg_name"]["value"] == "foo-asg"
