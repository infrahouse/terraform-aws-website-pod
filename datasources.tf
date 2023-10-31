data "aws_caller_identity" "current" {}

data "aws_subnet" "selected" {
  id = var.subnets[0]
}

data "aws_route53_zone" "webserver_zone" {
  zone_id = var.zone_id
}
