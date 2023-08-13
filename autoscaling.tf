resource "aws_autoscaling_policy" "cpu_load" {
  autoscaling_group_name = aws_autoscaling_group.website.name
  name                   = aws_autoscaling_group.website.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.autoscaling_target_cpu_load
  }
}
