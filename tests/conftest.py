from pprint import pformat
from time import sleep

import logging

from infrahouse_core.logging import setup_logging

DEFAULT_PROGRESS_INTERVAL = 10
TEST_TIMEOUT = 3600
UBUNTU_CODENAME = "noble"

LOG = logging.getLogger()
TERRAFORM_ROOT_DIR = "test_data"

setup_logging(LOG, debug=True)


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
