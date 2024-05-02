module "webserver_profile" {
  source       = "registry.infrahouse.com/infrahouse/instance-profile/aws"
  version      = "1.3.3"
  profile_name = var.instance_profile
  permissions  = var.webserver_permissions
}
