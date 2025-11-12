resource "aws_route53_record" "extra" {
  provider = aws.dns
  count    = var.assume_dns ? length(var.dns_a_records) : 0
  zone_id  = var.zone_id
  name     = trimprefix(join(".", [var.dns_a_records[count.index], data.aws_route53_zone.webserver_zone.name]), ".")
  type     = "A"
  alias {
    name                   = aws_alb.website.dns_name
    zone_id                = aws_alb.website.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "extra_caa_amazon" {
  provider = aws.dns
  count    = var.assume_dns ? length(var.dns_a_records) : 0
  zone_id  = var.zone_id
  name     = trimprefix(join(".", [var.dns_a_records[count.index], data.aws_route53_zone.webserver_zone.name]), ".")
  type     = "CAA"
  ttl      = 300
  records = concat(
    [for issuer in var.certificate_issuers : "0 issue \"${issuer}\""],
    ["0 issuewild \";\""]
  )
}
