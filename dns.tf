resource "aws_route53_record" "extra" {
  provider = aws.dns
  count    = var.assume_dns ? length(var.dns_a_records) : 0
  zone_id  = var.zone_id
  name     = trimprefix(join(".", [var.dns_a_records[count.index], data.aws_route53_zone.webserver_zone.name]), ".")
  type     = "A"

  # Weighted routing support for zero-downtime migrations
  set_identifier = var.dns_routing_policy != "simple" ? var.dns_set_identifier : null

  dynamic "weighted_routing_policy" {
    for_each = var.dns_routing_policy == "weighted" ? [1] : []
    content {
      weight = var.dns_weight
    }
  }

  alias {
    name                   = aws_alb.website.dns_name
    zone_id                = aws_alb.website.zone_id
    evaluate_target_health = true
  }

  lifecycle {
    precondition {
      condition     = var.dns_routing_policy == "simple" || var.dns_set_identifier != null
      error_message = <<-EOF
        When using dns_routing_policy = "weighted", you must also set dns_set_identifier.

        Current configuration:
          - dns_routing_policy: ${var.dns_routing_policy}
          - dns_set_identifier: ${var.dns_set_identifier == null ? "null (not set)" : var.dns_set_identifier}

        Route53 weighted routing records require a unique set_identifier to distinguish
        between multiple records with the same name.

        Solution:
          dns_routing_policy = "weighted"
          dns_set_identifier = "my-service-v1"
      EOF
    }
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
    var.allow_wildcard_certificates ? [for issuer in var.certificate_issuers : "0 issuewild \"${issuer}\""] : ["0 issuewild \";\""]
  )
}
