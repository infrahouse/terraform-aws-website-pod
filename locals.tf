locals {
  module         = "infrahouse/website-pod/aws"
  module_version = "5.8.2"
  default_module_tags = merge(
    {
      environment : var.environment
      service : var.service_name
      account : data.aws_caller_identity.current.account_id
      created_by_module : local.module
    },
    var.upstream_module != null ? {
      upstream_module : var.upstream_module
    } : {},
    local.vanta_tags,
    var.tags
  )

  default_asg_tags = merge(
    {
      Name : var.service_name
    },
    local.default_module_tags,
    data.aws_default_tags.provider.tags,
  )

  vanta_tags = merge(
    var.vanta_owner != null ? {
      VantaOwner : var.vanta_owner
    } : {},
    {
      VantaNonProd : !contains(var.vanta_production_environments, var.environment)
      VantaContainsUserData : var.vanta_contains_user_data
      VantaContainsEPHI : var.vanta_contains_ephi
    },
    var.vanta_description != null ? {
      VantaDescription : var.vanta_description
    } : {},
    var.vanta_user_data_stored != null ? {
      VantaUserDataStored : var.vanta_user_data_stored
    } : {},
    var.vanta_no_alert != null ? {
      VantaNoAlert : var.vanta_no_alert
    } : {}
  )

  min_elb_capacity = var.asg_min_elb_capacity != null ? var.asg_min_elb_capacity : var.asg_min_size
  # See https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html
  elb_account_map = {
    "us-east-1" : "127311923021"
    "us-east-2" : "033677994240"
    "us-west-1" : "027434742980"
    "us-west-2" : "797873946194"

  }
}
