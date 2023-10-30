resource "aws_route53_record" "extra" {
  count   = length(var.dns_a_records)
  zone_id = var.zone_id
  name    = trimprefix(join(".", [var.dns_a_records[count.index], data.aws_route53_zone.webserver_zone.name]), ".")
  type    = "A"
  alias {
    name                   = aws_alb.website.dns_name
    zone_id                = aws_alb.website.zone_id
    evaluate_target_health = true
  }
}
