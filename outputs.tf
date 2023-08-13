output "dns_name" {
  value = aws_alb.website.dns_name
}

output "zone_id" {
  value = aws_alb.website.zone_id
}
