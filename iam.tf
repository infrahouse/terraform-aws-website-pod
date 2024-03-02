module "webserver_profile" {
  source       = "git::https://github.com/infrahouse/terraform-aws-instance-profile.git?ref=1.3.0"
  profile_name = var.instance_profile
  permissions  = var.webserver_permissions
}
