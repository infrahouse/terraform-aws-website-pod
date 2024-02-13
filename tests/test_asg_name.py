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
                asg_name = "foo-asg"
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
        assert tf_output["asg_name"]["value"] == "foo-asg"
