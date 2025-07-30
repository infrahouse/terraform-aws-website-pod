from pprint import pformat
from textwrap import dedent
from time import sleep

import pytest
import logging
from os import path as osp

from infrahouse_core.logging import setup_logging
from infrahouse_toolkit.terraform import terraform_apply

DEFAULT_PROGRESS_INTERVAL = 10
TEST_TIMEOUT = 3600
TRACE_TERRAFORM = False
UBUNTU_CODENAME = "jammy"

LOG = logging.getLogger(__name__)
TEST_ZONE = "ci-cd.infrahouse.com"
TERRAFORM_ROOT_DIR = "test_data"

setup_logging(LOG, debug=True)


@pytest.fixture(scope="session")
def instance_profile(keep_after, test_role_arn, aws_region):
    terraform_module_dir = osp.join(TERRAFORM_ROOT_DIR, "instance_profile")

    with open(osp.join(terraform_module_dir, "terraform.tfvars"), "w") as fp:
        fp.write(
            dedent(
                f"""
                region   = "{aws_region}"
                role_arn = "{test_role_arn}"
                """
            )
        )

    with terraform_apply(
        terraform_module_dir,
        destroy_after=not keep_after,
        json_output=True,
        enable_trace=TRACE_TERRAFORM,
    ) as tf_output:
        yield tf_output


def wait_for_instance_refresh(asg_name, autoscaling_client):
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

        return
