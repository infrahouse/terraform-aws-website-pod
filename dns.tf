resource "aws_route53_record" "primary" {
  zone_id = data.aws_route53_zone.website.id
  name    = var.dns_zone
  type    = "A"
  alias {
    name                   = aws_alb.website.dns_name
    zone_id                = aws_alb.website.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "extra" {
  count   = length(var.dns_a_records_extra)
  zone_id = data.aws_route53_zone.website.id
  name    = var.dns_a_records_extra[count.index]
  type    = "A"
  alias {
    name                   = aws_alb.website.dns_name
    zone_id                = aws_alb.website.zone_id
    evaluate_target_health = true
  }
}
