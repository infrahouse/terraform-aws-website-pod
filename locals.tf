locals {
  default_module_tags = {
    environment : var.environment
    service : var.service_name
    account : data.aws_caller_identity.current.account_id
    created_by_module : "infrahouse/website-pod/aws"

  }
  default_asg_tags = merge(
    {
      Name : "webserver"
    },
    local.default_module_tags
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
