resource "aws_security_group" "backend" {
  description = "Backend security group for service ${var.service_name}"
  name_prefix = "web-"
  vpc_id      = data.aws_subnet.selected.vpc_id

  tags = merge(
    {
      Name : "${var.service_name} backend"
    },
    local.default_module_tags
  )
}

resource "aws_vpc_security_group_ingress_rule" "backend_ssh_local" {
  description       = "SSH access from the service ${var.service_name} VPC"
  security_group_id = aws_security_group.backend.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = data.aws_vpc.service.cidr_block
  tags = merge(
    {
      Name = "SSH local"
    },
    local.default_module_tags
  )
}

resource "aws_vpc_security_group_ingress_rule" "backend_ssh_input" {
  count             = var.ssh_cidr_block != null ? 1 : 0
  description       = "SSH access from the user-specified CIDR range."
  security_group_id = aws_security_group.backend.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = var.ssh_cidr_block
  tags = merge(
    {
      Name = "SSH additional"
    },
    local.default_module_tags
  )
}

resource "aws_vpc_security_group_ingress_rule" "backend_user_traffic" {
  description                  = "Any traffic from the Load Balancer"
  security_group_id            = aws_security_group.backend.id
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.alb.id
  tags = merge(
    {
      Name = "Load balancer traffic"
    },
    local.default_module_tags,
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "backend_healthcheck" {
  # Add the rule only if the healthcheck port is different from the traffic port
  count             = var.alb_healthcheck_port == var.target_group_port || var.alb_healthcheck_port == "traffic-port" ? 0 : 1
  description       = "Health checks from the Load Balancer"
  security_group_id = aws_security_group.backend.id
  from_port         = var.alb_healthcheck_port
  to_port           = var.alb_healthcheck_port
  ip_protocol       = "tcp"
  cidr_ipv4         = data.aws_vpc.service.cidr_block
  tags = merge(
    local.default_module_tags,
    {
      Name = "healthcheck"
    },
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "backend_icmp" {
  description       = "Allow all ICMP traffic"
  security_group_id = aws_security_group.backend.id
  from_port         = -1
  to_port           = -1
  ip_protocol       = "icmp"
  cidr_ipv4         = "0.0.0.0/0"
  tags = merge(
    local.default_module_tags,
    {
      Name = "ICMP traffic"
    },
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
}


resource "aws_vpc_security_group_egress_rule" "backend_outgoing" {
  security_group_id = aws_security_group.backend.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  tags = merge(
    local.default_module_tags,
    {
      Name = "outgoing traffic"
    },
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
}
