resource "aws_alb" "website" {
  name_prefix                = var.alb_name_prefix
  enable_deletion_protection = var.enable_deletion_protection
  subnets                    = var.subnets
  idle_timeout               = var.alb_idle_timeout
  security_groups = [
    aws_security_group.alb.id
  ]
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
  }
  min_elb_capacity = var.asg_min_elb_capacity != null ? var.asg_min_elb_capacity : var.asg_min_size
}

resource "aws_autoscaling_group" "website" {
  name_prefix               = aws_launch_template.website.name_prefix
  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  min_elb_capacity          = local.min_elb_capacity
  vpc_zone_identifier       = var.backend_subnets
  health_check_type         = var.health_check_type
  wait_for_capacity_timeout = var.wait_for_capacity_timeout
  max_instance_lifetime     = var.max_instance_lifetime_days * 24 * 3600
  health_check_grace_period = var.health_check_grace_period
  protect_from_scale_in     = var.protect_from_scale_in
  target_group_arns = var.attach_tagret_group_to_asg == true ? [
    aws_alb_target_group.website.arn
  ] : []
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage       = var.min_healthy_percentage
      scale_in_protected_instances = var.asg_scale_in_protected_instances
    }
    triggers = ["tag"]
  }
  launch_template {
    id      = aws_launch_template.website.id
    version = aws_launch_template.website.latest_version
  }
  dynamic "tag" {
    for_each = merge(
      local.default_asg_tags,
      var.tags
    )
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true

    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_template" "website" {
  name_prefix   = var.alb_name_prefix
  image_id      = var.ami
  instance_type = var.instance_type
  user_data     = var.userdata
  key_name      = var.key_pair_name
  vpc_security_group_ids = concat(
    [aws_security_group.backend.id],
    var.extra_security_groups_backend
  )
  iam_instance_profile {
    arn = module.webserver_profile.instance_profile_arn
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.root_volume_size
      delete_on_termination = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }

}
