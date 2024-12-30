output "network_subnet_public_ids" {
  value = var.lb_subnet_ids
}

output "network_subnet_private_ids" {
  value = var.backend_subnet_ids
}

output "network_subnet_all_ids" {
  value = concat(var.backend_subnet_ids, var.lb_subnet_ids)
}

output "private_key_pem" {
  sensitive = true
  value     = module.truststore.ca-key
}
output "tls_self_signed_cert" {
  value = module.truststore.ca-pem
}
