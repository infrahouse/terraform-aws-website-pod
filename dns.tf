resource "aws_route53_record" "extra" {
  count    = length(var.dns_a_records)
  provider = aws.dns
  zone_id  = var.zone_id
  name     = trimprefix(join(".", [var.dns_a_records[count.index], data.aws_route53_zone.webserver_zone.name]), ".")
  type     = "CNAME"
  records = [
    aws_alb.website.dns_name
  ]
}
