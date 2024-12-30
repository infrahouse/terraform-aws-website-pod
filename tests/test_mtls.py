import json
from os import path as osp
from textwrap import dedent

import pytest
from infrahouse_toolkit.terraform import terraform_apply

from tests.conftest import (
    TEST_ZONE,
    UBUNTU_CODENAME,
    TRACE_TERRAFORM,
    TEST_TIMEOUT,
)


@pytest.mark.timeout(TEST_TIMEOUT)
def test_mtls(
    service_network,
    keep_after,
    aws_region,
    test_role_arn,
    test_zone_name,
):
    subnet_public_ids = service_network["subnet_public_ids"]["value"]
    subnet_private_ids = service_network["subnet_private_ids"]["value"]
    internet_gateway_id = service_network["internet_gateway_id"]["value"]

    terraform_dir = "test_data/test_mtls"

    with open(osp.join(terraform_dir, "terraform.tfvars"), "w") as fp:
        fp.write(
            dedent(
                f"""
                region              = "{aws_region}"
                dns_zone            = "{test_zone_name}"
                ubuntu_codename     = "{UBUNTU_CODENAME}"
                lb_subnet_ids       = {json.dumps(subnet_public_ids)}
                backend_subnet_ids  = {json.dumps(subnet_private_ids)}
                internet_gateway_id = "{internet_gateway_id}"
                """
            )
        )
        if test_role_arn:
            fp.write(
                dedent(
                    f"""
                    role_arn            = "{test_role_arn}"
                    """
                )
            )

    with terraform_apply(
        terraform_dir,
        destroy_after=not keep_after,
        json_output=True,
        enable_trace=TRACE_TERRAFORM,
    ) as tf_output:
        print(tf_output["private_key_pem"]["value"])
        print(tf_output["tls_self_signed_cert"]["value"])
        assert True
