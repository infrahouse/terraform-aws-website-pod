resource "random_string" "profile_suffix" {
  length  = 12
  special = false
  upper   = false
}

module "instance_profile" {
  source          = "registry.infrahouse.com/infrahouse/instance-profile/aws"
  version         = "1.6.1"
  profile_name    = "${var.service_name}-instance-${random_string.profile_suffix.result}"
  role_name       = var.instance_role_name
  permissions     = var.instance_profile_permissions == null ? data.aws_iam_policy_document.default_permissions.json : var.instance_profile_permissions
  upstream_module = "infrahouse/terraform-aws-website-pod/aws"
  tags = merge(
    local.default_module_tags,
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
}
