data "aws_caller_identity" "current" {}

data "aws_subnet" "selected" {
  id = var.subnets[0]
}

data "aws_route53_zone" "webserver_zone" {
  provider = aws.dns
  zone_id  = var.zone_id
}

# Public IP Addresses on the ALB
data "aws_network_interface" "alb" {
  for_each = toset(var.subnets)

  filter {
    name   = "description"
    values = ["ELB ${aws_alb.website.arn_suffix}"]
  }

  filter {
    name   = "subnet-id"
    values = [each.value]
  }
}
