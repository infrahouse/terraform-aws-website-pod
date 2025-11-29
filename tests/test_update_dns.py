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
def test_update_dns(
    service_network,
    keep_after,
    aws_region,
    test_role_arn,
    subzone,
):
    subnet_public_ids = service_network["subnet_public_ids"]["value"]
    subnet_private_ids = service_network["subnet_private_ids"]["value"]
    internet_gateway_id = service_network["internet_gateway_id"]["value"]
    zone_id = subzone["subzone_id"]["value"]

    terraform_dir = "test_data/test_create_lb"

    instance_name = "foo-app"
    with open(osp.join(terraform_dir, "terraform.tfvars"), "w") as fp:
        fp.write(
            dedent(
                f"""
                region          = "{aws_region}"
                zone_id         = "{zone_id}"
                ubuntu_codename = "{UBUNTU_CODENAME}"
                tags = {{
                    Name: "{instance_name}"
                }}
                lb_subnet_ids = {json.dumps(subnet_public_ids)}
                backend_subnet_ids = {json.dumps(subnet_private_ids)}
                internet_gateway_id = "{internet_gateway_id}"
                """
            )
        )
        if test_role_arn:
            fp.write(
                dedent(
                    f"""
                    role_arn      = "{test_role_arn}"
                    """
                )
            )

    # Create website pod first time
    with terraform_apply(
        terraform_dir,
        destroy_after=not keep_after,
        json_output=True,
    ) as tf_output:
        assert len(tf_output["network_subnet_private_ids"]) == 3
        assert len(tf_output["network_subnet_public_ids"]) == 3

        # Update DNS records
        with open(osp.join(terraform_dir, "terraform.tfvars"), "w") as fp:
            fp.write(
                dedent(
                    f"""
                        region          = "{aws_region}"
                        zone_id         = "{zone_id}"
                        ubuntu_codename = "{UBUNTU_CODENAME}"
                        tags = {{
                            Name: "{instance_name}"
                        }}
                        dns_a_records = ["", "www"]

                        lb_subnet_ids = {json.dumps(subnet_public_ids)}
                        backend_subnet_ids = {json.dumps(subnet_private_ids)}
                        internet_gateway_id = "{internet_gateway_id}"
                        """
                )
            )
            if test_role_arn:
                fp.write(
                    dedent(
                        f"""
                        role_arn      = "{test_role_arn}"
                        """
                    )
                )
        # Make sure the second apply succeeds
        with terraform_apply(
            terraform_dir,
            destroy_after=not keep_after,
            json_output=True,
        ):
            assert True
