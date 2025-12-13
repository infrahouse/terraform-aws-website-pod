# SNS Topic for alarm notifications
resource "aws_sns_topic" "alarms" {
  count = length(var.alarm_emails) > 0 ? 1 : 0

  name              = "${aws_autoscaling_group.website.name}-alb-alarms"
  display_name      = "ALB Alarms for ${aws_autoscaling_group.website.name}"
  kms_master_key_id = "alias/aws/sns" # Encrypt SNS topic

  tags = merge(
    local.default_module_tags,
    {
      Name        = "${aws_autoscaling_group.website.name}-alb-alarms"
      description = "CloudWatch alarms for ALB monitoring - Vanta compliance"
    }
  )
}

# Email subscriptions for the alarm topic
resource "aws_sns_topic_subscription" "alarm_emails" {
  count = length(var.alarm_emails)

  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_emails[count.index]
}

# CloudWatch Alarm: Unhealthy Host Count
resource "aws_cloudwatch_metric_alarm" "unhealthy_host_count" {
  count = local.alarms_enabled ? 1 : 0

  alarm_name          = "${aws_autoscaling_group.website.name}-unhealthy-hosts"
  alarm_description   = "Triggers when unhealthy host count exceeds ${var.alarm_unhealthy_host_threshold} (Vanta compliance)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60 # 1 minute
  statistic           = "Average"
  threshold           = var.alarm_unhealthy_host_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_alb.website.arn_suffix
    TargetGroup  = aws_alb_target_group.website.arn_suffix
  }

  alarm_actions = local.alarm_sns_topics
  ok_actions    = local.alarm_sns_topics

  tags = merge(
    local.default_module_tags,
    {
      Name = "${aws_autoscaling_group.website.name}-unhealthy-hosts"
    }
  )
}

# CloudWatch Alarm: Target Response Time (Latency)
resource "aws_cloudwatch_metric_alarm" "target_response_time" {
  count = local.alarms_enabled ? 1 : 0

  alarm_name          = "${aws_autoscaling_group.website.name}-high-latency"
  alarm_description   = "Triggers when target response time exceeds ${local.alarm_target_response_time}s (Vanta compliance)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60 # 1 minute
  statistic           = "Average"
  threshold           = local.alarm_target_response_time
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_alb.website.arn_suffix
  }

  alarm_actions = local.alarm_sns_topics
  ok_actions    = local.alarm_sns_topics

  tags = merge(
    local.default_module_tags,
    {
      Name = "${aws_autoscaling_group.website.name}-high-latency"
    }
  )
}

# CloudWatch Alarm: Low Success Rate (Server Errors)
resource "aws_cloudwatch_metric_alarm" "low_success_rate" {
  count = local.alarms_enabled ? 1 : 0

  alarm_name          = "${aws_autoscaling_group.website.name}-low-success-rate"
  alarm_description   = "Triggers when success rate drops below ${var.alarm_success_rate_threshold}% (Vanta compliance)"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  threshold           = var.alarm_success_rate_threshold
  treat_missing_data  = "notBreaching"

  # Calculate success rate using metric math
  # Success rate = 100 * (1 - (target_5xx + elb_5xx) / request_count)
  # FILL() handles empty series: if no requests, returns 1 to avoid division by zero; if no errors, treats as 0
  metric_query {
    id          = "success_rate"
    expression  = "100 * (1 - (FILL(target_5xx, 0) + FILL(elb_5xx, 0)) / FILL(request_count, 1))"
    label       = "Success Rate (%)"
    return_data = true
  }

  # Total request count
  metric_query {
    id = "request_count"
    metric {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      period      = var.alarm_success_rate_period
      stat        = "Sum"
      dimensions = {
        LoadBalancer = aws_alb.website.arn_suffix
      }
    }
  }

  # Target 5xx errors (backend server errors)
  metric_query {
    id = "target_5xx"
    metric {
      metric_name = "HTTPCode_Target_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = var.alarm_success_rate_period
      stat        = "Sum"
      dimensions = {
        LoadBalancer = aws_alb.website.arn_suffix
      }
    }
  }

  # ELB 5xx errors (load balancer errors)
  metric_query {
    id = "elb_5xx"
    metric {
      metric_name = "HTTPCode_ELB_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = var.alarm_success_rate_period
      stat        = "Sum"
      dimensions = {
        LoadBalancer = aws_alb.website.arn_suffix
      }
    }
  }

  alarm_actions = local.alarm_sns_topics
  ok_actions    = local.alarm_sns_topics

  tags = merge(
    local.default_module_tags,
    {
      Name = "${aws_autoscaling_group.website.name}-low-success-rate"
    }
  )
}

# CloudWatch Alarm: High CPU Utilization
resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
  count = local.alarms_enabled ? 1 : 0

  alarm_name          = "${aws_autoscaling_group.website.name}-high-cpu"
  alarm_description   = "Triggers when ASG CPU exceeds ${local.alarm_cpu_threshold}% for ${var.alarm_evaluation_periods * 5} minutes, indicating autoscaling failure (Vanta compliance)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300 # 5 minutes
  statistic           = "Average"
  threshold           = local.alarm_cpu_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.website.name
  }

  alarm_actions = local.alarm_sns_topics
  ok_actions    = local.alarm_sns_topics

  tags = merge(
    local.default_module_tags,
    {
      Name = "${aws_autoscaling_group.website.name}-high-cpu"
    }
  )
}
