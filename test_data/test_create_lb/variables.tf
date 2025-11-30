variable "region" {}
variable "role_arn" {
  default = null
}
variable "dns_a_records" {
  default = ["", "www", "bogus-test-stuff"]
}
variable "zone_id" {}
variable "ubuntu_codename" {}
variable "tags" {}
variable "asg_name" { default = null }

variable "backend_subnet_ids" {}
variable "lb_subnet_ids" {}
variable "internet_gateway_id" {}
variable "instance_role_name" { default = null }

variable "alarm_emails" {
  type    = list(string)
  default = ["devnull@infrahouse.com"]
}
