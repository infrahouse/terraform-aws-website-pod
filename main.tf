resource "aws_alb" "website" {
  name_prefix                = var.alb_name_prefix
  enable_deletion_protection = var.enable_deletion_protection
  subnets                    = var.subnets
  idle_timeout               = var.alb_idle_timeout
  # ALB is internal if subnets don't auto-assign public IPs
  # Otherwise, it's internet-facing (publicly accessible)
  internal = !data.aws_subnet.selected.map_public_ip_on_launch
  security_groups = [
    aws_security_group.alb.id
  ]
  dynamic "access_logs" {
    for_each = var.alb_access_log_enabled ? [{}] : []
    content {
      bucket  = aws_s3_bucket.access_log[0].bucket
      enabled = var.alb_access_log_enabled
    }
  }
  tags = merge(
    local.default_module_tags,
    local.access_log_tags,
    {
      module_version : local.module_version
    },

    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
}

locals {
  access_log_tags = var.alb_access_log_enabled ? {
    access_log_bucket : aws_s3_bucket.access_log[0].bucket
    access_log_bucket_policy : aws_s3_bucket_policy.access_logs[0].id
  } : {}
}

resource "aws_alb_listener" "redirect_to_ssl" {
  load_balancer_arn = aws_alb.website.arn
  port              = var.alb_listener_port
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
  tags = merge(
    local.default_module_tags,
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
}

resource "aws_lb_listener" "ssl" {
  load_balancer_arn = aws_alb.website.arn
  port              = 443
  protocol          = "HTTPS"
  # https://docs.aws.amazon.com/elasticloadbalancing/latest/application/describe-ssl-policies.html
  ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-Ext1-2021-06"
  certificate_arn = aws_acm_certificate.website.arn
  default_action {
    type = "fixed-response"
    fixed_response {
      status_code  = "400"
      content_type = "text/plain"
      message_body = "The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing)."
    }
  }
  depends_on = [
    aws_acm_certificate_validation.website
  ]
  tags = merge(
    local.default_module_tags,
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
}

resource "aws_alb_listener_rule" "website" {
  listener_arn = aws_lb_listener.ssl.arn
  # Priority is fixed at 99, leaving room for users to add custom rules:
  # - Priorities 1-98: Higher priority (evaluated before this rule)
  # - Priorities 100+: Lower priority (evaluated after this rule)
  priority = 99
  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.website.arn
  }
  condition {
    host_header {
      values = [
        for record in var.dns_a_records : trimprefix(join(".", [record, data.aws_route53_zone.webserver_zone.name]), ".")
      ]
    }
  }
  tags = merge(
    local.default_module_tags,
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
}

resource "aws_alb_target_group" "website" {
  port                 = var.target_group_port
  protocol             = "HTTP"
  target_type          = var.target_group_type
  vpc_id               = data.aws_subnet.selected.vpc_id
  deregistration_delay = var.target_group_deregistration_delay

  load_balancing_algorithm_type = var.load_balancing_algorithm_type
  stickiness {
    type    = "lb_cookie"
    enabled = var.stickiness_enabled
  }

  health_check {
    enabled             = var.alb_healthcheck_enabled
    path                = var.alb_healthcheck_path
    port                = var.alb_healthcheck_port
    protocol            = var.alb_healthcheck_protocol
    healthy_threshold   = var.alb_healthcheck_healthy_threshold
    unhealthy_threshold = local.unhealthy_threshold
    interval            = var.alb_healthcheck_interval
    timeout             = var.alb_healthcheck_timeout
    matcher             = var.alb_healthcheck_response_code_matcher
  }
  tags = merge(
    local.default_module_tags,
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )

}
