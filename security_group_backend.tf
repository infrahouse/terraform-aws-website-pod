resource "aws_security_group" "backend" {
  description = "Backend security group for service ${var.service_name}"
  name_prefix = "web-"
  vpc_id      = data.aws_subnet.selected.vpc_id

  tags = {
    Name : "${var.service_name} backend"
  }
}

resource "aws_vpc_security_group_ingress_rule" "backend_ssh_local" {
  description       = "SSH access from the service ${var.service_name} VPC"
  security_group_id = aws_security_group.backend.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = data.aws_vpc.service.cidr_block
  tags = {
    Name = "SSH local"
  }
}

resource "aws_vpc_security_group_ingress_rule" "backend_ssh_input" {
  description       = "SSH access from the service specified CIDR range"
  security_group_id = aws_security_group.backend.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = var.ssh_cidr_block
  tags = {
    Name = "SSH additional"
  }
}

resource "aws_vpc_security_group_ingress_rule" "backend_user_traffic" {
  description       = "User traffic from the Load Balancer"
  security_group_id = aws_security_group.backend.id
  from_port         = var.target_group_port
  to_port           = var.target_group_port
  ip_protocol       = "tcp"
  cidr_ipv4         = data.aws_vpc.service.cidr_block
  tags = {
    Name = "user traffic"
  }
}

resource "aws_vpc_security_group_ingress_rule" "backend_healthcheck" {
  # Add the rule only if the healthcheck port is different from the traffic port
  count             = var.alb_healthcheck_port != var.target_group_port ? 1 : 0
  description       = "Health checks from the Load Balancer"
  security_group_id = aws_security_group.backend.id
  from_port         = var.alb_healthcheck_port
  to_port           = var.alb_healthcheck_port
  ip_protocol       = "tcp"
  cidr_ipv4         = data.aws_vpc.service.cidr_block
  tags = {
    Name = "healthcheck"
  }
}

resource "aws_vpc_security_group_ingress_rule" "backend_icmp" {
  description       = "Allow all ICMP traffic"
  security_group_id = aws_security_group.backend.id
  from_port         = -1
  to_port           = -1
  ip_protocol       = "icmp"
  cidr_ipv4         = "0.0.0.0/0"
  tags = {
    Name = "ICMP traffic"
  }
}


resource "aws_vpc_security_group_egress_rule" "backend_outgoing" {
  security_group_id = aws_security_group.backend.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  tags = {
    Name = "outgoing traffic"
  }
}
