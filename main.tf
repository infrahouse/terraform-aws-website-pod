resource "aws_alb" "website" {
  name_prefix                = var.alb_name_prefix
  enable_deletion_protection = var.enable_deletion_protection
  subnets                    = var.subnets
  idle_timeout               = var.alb_idle_timeout
  internal                   = var.alb_internal
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
    {
      environment : var.environment
      service : var.service_name
      managed-by : "terraform"
      account : data.aws_caller_identity.current.account_id

    },
    local.access_log_tags
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
}

resource "aws_lb_listener" "ssl" {
  load_balancer_arn = aws_alb.website.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = ""
  certificate_arn   = aws_acm_certificate.website.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.website.arn
  }
  depends_on = [
    aws_acm_certificate_validation.website
  ]
}

resource "aws_alb_target_group" "website" {
  port        = var.target_group_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = data.aws_subnet.selected.vpc_id
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
    unhealthy_threshold = var.alb_healthcheck_uhealthy_threshold
    interval            = var.alb_healthcheck_interval
    timeout             = var.alb_healthcheck_timeout
    matcher             = var.alb_healthcheck_response_code_matcher
  }

}

locals {
  default_asg_tags = {
    Name : "webserver"
    environment : var.environment
    service : var.service_name
    managed-by : "terraform"
    account : data.aws_caller_identity.current.account_id
    created_by_module : "infrahouse/website-pod/aws"
  }
  min_elb_capacity = var.asg_min_elb_capacity != null ? var.asg_min_elb_capacity : var.asg_min_size
}
