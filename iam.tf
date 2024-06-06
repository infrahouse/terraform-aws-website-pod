resource "random_string" "profile_suffix" {
  length  = 12
  special = false
  upper   = false
}

module "instance_profile" {
  count        = var.instance_profile_name == null ? 1 : 0
  source       = "registry.infrahouse.com/infrahouse/instance-profile/aws"
  version      = "1.3.3"
  profile_name = "${var.service_name}-instance-${random_string.profile_suffix.result}"
  permissions  = var.instance_profile_permissions == null ? data.aws_iam_policy_document.default_permissions.json : var.instance_profile_permissions
}
