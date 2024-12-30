module "truststore" {
  source  = "infrahouse/truststore/aws"
  version = "~> 0.3"
  ca_key_readers = [
    module.frontend.instance_role_arn,
  ]
  ca_pem_readers = [
    module.frontend.instance_role_arn,
  ]
}

