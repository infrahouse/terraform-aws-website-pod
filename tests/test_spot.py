import json
from os import path as osp
from pprint import pformat
from textwrap import dedent

import pytest
from infrahouse_toolkit.terraform import terraform_apply

from tests.conftest import (
    TEST_ZONE,
    UBUNTU_CODENAME,
    TRACE_TERRAFORM,
    TEST_TIMEOUT,
    wait_for_instance_refresh,
    LOG,
)


@pytest.mark.timeout(TEST_TIMEOUT)
def test_lb(
    service_network,
    autoscaling_client,
    keep_after,
    aws_region,
):
    subnet_public_ids = service_network["subnet_public_ids"]["value"]
    subnet_private_ids = service_network["subnet_private_ids"]["value"]
    internet_gateway_id = service_network["internet_gateway_id"]["value"]

    terraform_dir = "test_data/test_spot"

    with open(osp.join(terraform_dir, "terraform.tfvars"), "w") as fp:
        fp.write(
            dedent(
                f"""
                region          = "{aws_region}"
                dns_zone        = "{TEST_ZONE}"
                ubuntu_codename = "{UBUNTU_CODENAME}"

                lb_subnet_ids       = {json.dumps(subnet_public_ids)}
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
        healthy_instance_count = len(
            [
                i
                for i in response["AutoScalingGroups"][0]["Instances"]
                if i["LifecycleState"] == "InService"
            ]
        )
        assert healthy_instance_count == 2
