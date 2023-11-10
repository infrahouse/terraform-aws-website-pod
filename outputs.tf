output "dns_name" {
  description = "DNA namae of the load balancer."
  value       = aws_alb.website.dns_name
}

output "zone_id" {
  description = "Zone id where A records are created for the service."
  value       = aws_alb.website.zone_id
}

output "target_group_arn" {
  description = "Target group ARN that listens to the service port."
  value       = aws_alb_target_group.website.arn
}

output "asg_arn" {
  description = "ARN of the created autoscaling group"
  value       = aws_autoscaling_group.website.arn
}

output "asg_name" {
  description = "Name of the created autoscaling group"
  value       = aws_autoscaling_group.website.name
}

output "alb_public_ips" {
  description = "List of public IPv4 addresses assigned to the load balancer."
  value       = local.a_list
}
