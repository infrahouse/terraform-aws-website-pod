resource "aws_acm_certificate" "website" {
  domain_name       = var.dns_zone
  validation_method = "DNS"
  subject_alternative_names = [
    for record in var.dns_a_records_extra : "${record}.${var.dns_zone}"
  ]
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.website.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  zone_id = data.aws_route53_zone.website.id
  name    = each.value.name
  type    = each.value.type
  records = [
    each.value.record
  ]
  ttl = 60
}

resource "aws_acm_certificate_validation" "website" {
  certificate_arn = aws_acm_certificate.website.arn
  validation_record_fqdns = [
    for d in aws_route53_record.cert_validation : d.fqdn
  ]
}
