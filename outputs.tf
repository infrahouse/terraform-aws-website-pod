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
