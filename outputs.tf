output "asg_arn" {
  description = "ARN of the created autoscaling group"
  value       = aws_autoscaling_group.website.arn
}

output "asg_name" {
  description = "Name of the created autoscaling group"
  value       = aws_autoscaling_group.website.name
}

output "dns_name" {
  description = "DNS name of the load balancer."
  value       = aws_alb.website.dns_name
}

output "instance_profile_name" {
  description = "EC2 instance profile name."
  value       = module.instance_profile.instance_profile_name
}

output "load_balancer_arn" {
  description = "Load Balancer ARN"
  value       = aws_alb.website.arn
}

output "load_balancer_dns_name" {
  description = "Load balancer DNS name."
  value       = aws_alb.website.dns_name
}

output "target_group_arn" {
  description = "Target group ARN that listens to the service port."
  value       = aws_alb_target_group.website.arn
}

output "load_balancing_algorithm_type" {
  description = "Load balancing algorithm used by the target group (round_robin or least_outstanding_requests)."
  value       = aws_alb_target_group.website.load_balancing_algorithm_type
}

output "zone_id" {
  description = "Zone id where A records are created for the service."
  value       = aws_alb.website.zone_id
}

output "backend_security_group" {
  description = "Map with security group id and rules"
  value = {
    backend : {
      id : aws_security_group.backend.id
      rules : merge(

        {
          backend_ssh_local : aws_vpc_security_group_ingress_rule.backend_ssh_local.id
          backend_ssh_input : var.ssh_cidr_block != null ? aws_vpc_security_group_ingress_rule.backend_ssh_input[0].id : null
          backend_user_traffic : aws_vpc_security_group_ingress_rule.backend_user_traffic.id
          backend_icmp : aws_vpc_security_group_ingress_rule.backend_icmp.id
          backend_outgoing : aws_vpc_security_group_egress_rule.backend_outgoing.id
        },
        var.alb_healthcheck_port == var.target_group_port || var.alb_healthcheck_port == "traffic-port" ? {} : {
          backend_healthcheck : aws_vpc_security_group_ingress_rule.backend_healthcheck[0].id
        }
      )
    }
  }
}

output "instance_role_arn" {
  description = "ARN of the instance role."
  value       = module.instance_profile.instance_role_arn
}

output "instance_role_name" {
  description = "Name of the instance role."
  value       = module.instance_profile.instance_role_name
}

output "instance_role_policy_name" {
  description = "Policy name attached to EC2 instance profile."
  value       = module.instance_profile.instance_role_policy_name
}

output "instance_role_policy_arn" {
  description = "Policy ARN attached to EC2 instance profile."
  value       = module.instance_profile.instance_role_policy_arn
}

output "instance_role_policy_attachment" {
  description = "Policy attachment id."
  value       = module.instance_profile.instance_role_policy_attachment
}

output "ssl_listener_arn" {
  description = "SSL listener ARN"
  value       = aws_lb_listener.ssl.arn
}

output "load_balancer_security_groups" {
  description = "Security groups associated with the load balancer"
  value       = aws_alb.website.security_groups
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate used by the load balancer"
  value       = aws_acm_certificate.website.arn
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "backend_security_group_id" {
  description = "ID of the backend instances security group"
  value       = aws_security_group.backend.id
}

# Vanta Compliance: CloudWatch Alarms
output "alarm_sns_topic_arn" {
  description = "ARN of the SNS topic for ALB CloudWatch alarms (if created). IMPORTANT: Email subscribers must confirm their subscription via the AWS confirmation email to receive notifications."
  value       = length(aws_sns_topic.alarms) > 0 ? aws_sns_topic.alarms[0].arn : null
}

output "alarm_sns_topic_name" {
  description = "Name of the SNS topic for ALB CloudWatch alarms (if created)"
  value       = length(aws_sns_topic.alarms) > 0 ? aws_sns_topic.alarms[0].name : null
}

output "cloudwatch_alarm_arns" {
  description = "ARNs of CloudWatch alarms created for ALB and ASG monitoring"
  value = {
    unhealthy_hosts  = length(aws_cloudwatch_metric_alarm.unhealthy_host_count) > 0 ? aws_cloudwatch_metric_alarm.unhealthy_host_count[0].arn : null
    high_latency     = length(aws_cloudwatch_metric_alarm.target_response_time) > 0 ? aws_cloudwatch_metric_alarm.target_response_time[0].arn : null
    low_success_rate = length(aws_cloudwatch_metric_alarm.low_success_rate) > 0 ? aws_cloudwatch_metric_alarm.low_success_rate[0].arn : null
    high_cpu         = length(aws_cloudwatch_metric_alarm.cpu_utilization) > 0 ? aws_cloudwatch_metric_alarm.cpu_utilization[0].arn : null
  }
}

