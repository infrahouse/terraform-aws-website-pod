data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

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

data "aws_ami" "selected" {
  filter {
    name = "image-id"
    values = [
      var.ami
    ]
  }
}

data "aws_iam_instance_profile" "passed" {
  count = var.instance_profile_name == null ? 0 : 1
  name  = var.instance_profile_name
}

data "aws_iam_policy_document" "default_permissions" {
  statement {
    actions = [
      "sts:GetCallerIdentity"
    ]
    resources = [
      "*"
    ]
  }

}
