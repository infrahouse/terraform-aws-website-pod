module "webserver_profile" {
  source       = "infrahouse/instance-profile/aws"
  version      = "~> 1.0"
  profile_name = var.instance_profile
  permissions  = var.webserver_permissions
}
