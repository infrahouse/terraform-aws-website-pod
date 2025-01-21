resource "aws_security_group" "alb" {
  description = "Load balancer security group for service ${var.service_name}"
  name_prefix = "web-"
  vpc_id      = data.aws_subnet.selected.vpc_id

  tags = merge(
    local.default_module_tags,
    {
      Name : "${var.service_name} load balancer"
    },
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "alb_listener_port" {
  description       = "User traffic to port ${var.alb_listener_port}"
  security_group_id = aws_security_group.alb.id
  from_port         = var.alb_listener_port
  to_port           = var.alb_listener_port
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  tags = merge(
    local.default_module_tags,
    {
      Name = "user traffic"
    },
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  description       = "User traffic to HTTPS port"
  security_group_id = aws_security_group.alb.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  tags = merge(
    local.default_module_tags,
    {
      Name = "https user traffic"
    },
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "alb_icmp" {
  description       = "Allow all ICMP traffic"
  security_group_id = aws_security_group.alb.id
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


resource "aws_vpc_security_group_egress_rule" "alb_outgoing" {
  security_group_id = aws_security_group.alb.id
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
