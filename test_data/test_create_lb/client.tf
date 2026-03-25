data "aws_ami" "infrahouse" {
  most_recent = true

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "tag:ubuntu_codename"
    values = [var.ubuntu_codename]
  }

  filter {
    name   = "tag:maintainer"
    values = ["infrahouse"]
  }

  owners = ["303467602807"] # InfraHouse
}

data "aws_iam_policy_document" "client_permissions" {
  statement {
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

module "client_profile" {
  source       = "registry.infrahouse.com/infrahouse/instance-profile/aws"
  version      = "1.9.0"
  profile_name = "foo-app-client"
  permissions  = data.aws_iam_policy_document.client_permissions.json
}

resource "aws_security_group" "client" {
  name_prefix = "client-"
  description = "Security group for test client instance"
  vpc_id      = data.aws_vpc.client.id
}

resource "aws_vpc_security_group_egress_rule" "client_outgoing" {
  description       = "Allow all outbound traffic"
  security_group_id = aws_security_group.client.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

data "aws_subnet" "client" {
  id = var.lb_subnet_ids[0]
}

data "aws_vpc" "client" {
  id = data.aws_subnet.client.vpc_id
}

resource "aws_instance" "client" {
  ami                         = data.aws_ami.infrahouse.id
  instance_type               = "t3.micro"
  subnet_id                   = var.lb_subnet_ids[0]
  key_name                    = aws_key_pair.test.key_name
  iam_instance_profile        = module.client_profile.instance_profile_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.client.id]
  tags = {
    Name : "foo-app-client"
  }
}
