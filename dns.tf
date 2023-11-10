locals {
  cname_list = [for r in var.dns_a_records : r if r != ""]
  a_list     = [for subnet in data.aws_network_interface.alb : subnet["association"][0]["public_ip"]]
}
resource "aws_route53_record" "extra" {
  count    = length(local.cname_list)
  provider = aws.dns
  zone_id  = var.zone_id
  name     = join(".", [local.cname_list[count.index], data.aws_route53_zone.webserver_zone.name])
  type     = "CNAME"
  ttl      = 300
  records = [
    aws_alb.website.dns_name
  ]
}

resource "aws_route53_record" "apex" {
  count    = contains(var.dns_a_records, "") ? 1 : 0
  provider = aws.dns
  zone_id  = var.zone_id
  name     = data.aws_route53_zone.webserver_zone.name
  type     = "A"
  ttl      = 300
  records  = local.a_list
}
