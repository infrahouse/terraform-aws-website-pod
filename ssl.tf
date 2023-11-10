resource "aws_acm_certificate" "website" {
  domain_name       = trimprefix(join(".", [var.dns_a_records[0], data.aws_route53_zone.webserver_zone.name]), ".")
  validation_method = "DNS"
  subject_alternative_names = [
    for record in var.dns_a_records : trimprefix(join(".", [record, data.aws_route53_zone.webserver_zone.name]), ".")
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
  provider = aws.dns
  zone_id  = var.zone_id
  name     = each.value.name
  type     = each.value.type
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
