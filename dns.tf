resource "aws_route53_record" "extra" {
  provider = aws.dns
  count    = var.create_caa_records ? length(var.dns_a_records) : 0
  zone_id  = var.zone_id
  name     = trimprefix(join(".", [var.dns_a_records[count.index], data.aws_route53_zone.webserver_zone.name]), ".")
  type     = "A"
  alias {
    name                   = aws_alb.website.dns_name
    zone_id                = aws_alb.website.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "caa_amazon" {
  provider = aws.dns
  count    = var.create_caa_records ? length(var.dns_a_records) : 0
  zone_id  = var.zone_id
  name     = trimprefix(join(".", [var.dns_a_records[count.index], data.aws_route53_zone.webserver_zone.name]), ".")
  type     = "CAA"
  ttl      = 300
  records = [
    "0 issue \"amazon.com\"",
    "0 issue \"amazontrust.com\"",
    "0 issue \"awstrust.com\"",
    "0 issue \"amazonaws.com\""
  ]
}
