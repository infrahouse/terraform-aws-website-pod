variable "region" {}
variable "role_arn" {}
variable "dns_a_records" {
  default = ["", "www", "bogus-test-stuff"]
}
variable "dns_zone" {}
variable "ubuntu_codename" {}
variable "tags" {}
variable "asg_name" { default = null }

variable "backend_subnet_ids" {}
variable "lb_subnet_ids" {}
variable "internet_gateway_id" {}
variable "instance_role_name" { default = null }
