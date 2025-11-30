output "network_subnet_public_ids" {
  value = var.lb_subnet_ids
}

output "network_subnet_private_ids" {
  value = var.backend_subnet_ids
}

output "network_subnet_all_ids" {
  value = concat(var.backend_subnet_ids, var.lb_subnet_ids)
}

output "asg_name" {
  value = module.lb.asg_name
}

output "instance_profile_name" {
  value = module.lb.instance_profile_name
}

output "load_balancer_dns_name" {
  value = module.lb.load_balancer_dns_name
}

output "test_zone_name" {
  description = "Full DNS zone name for testing (e.g., abcd.ci-cd.infrahouse.com)"
  value       = trim(data.aws_route53_zone.test_zone.name, ".")
}

# Vanta Compliance: CloudWatch Alarms
output "alarm_sns_topic_arn" {
  description = "ARN of the SNS topic for ALB CloudWatch alarms (if created)"
  value       = module.lb.alarm_sns_topic_arn
}

output "cloudwatch_alarm_arns" {
  description = "ARNs of CloudWatch alarms created for ALB and ASG monitoring"
  value       = module.lb.cloudwatch_alarm_arns
}
