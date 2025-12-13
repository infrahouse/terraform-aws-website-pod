import logging

from infrahouse_core.logging import setup_logging
from pytest_infrahouse.utils import wait_for_instance_refresh

DEFAULT_PROGRESS_INTERVAL = 10
TEST_TIMEOUT = 3600
UBUNTU_CODENAME = "noble"

LOG = logging.getLogger(__name__)
TERRAFORM_ROOT_DIR = "test_data"

setup_logging(LOG, debug=True, debug_botocore=False)
