data "aws_caller_identity" "current" {}

data "aws_subnet" "selected" {
  id = var.subnets[0]
}

data "aws_route53_zone" "webserver_zone" {
  provider = aws.dns
  zone_id  = var.zone_id
}

data "aws_vpc" "service" {
  id = data.aws_subnet.selected.vpc_id
}
