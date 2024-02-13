variable "region" {}
variable "dns_a_records" {
  default = ["", "www", "bogus-test-stuff"]
}
variable "dns_zone" {}
variable "ubuntu_codename" {}
variable "tags" {}
variable "asg_name" { default = null }
