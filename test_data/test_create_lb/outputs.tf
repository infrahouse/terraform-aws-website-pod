output "network_subnet_public_ids" {
  value = var.lb_subnet_ids
}

output "network_subnet_private_ids" {
  value = var.backend_subnet_ids
}

output "network_subnet_all_ids" {
  value = concat(var.backend_subnet_ids, var.lb_subnet_ids)
}

output "asg_name" {
  value = module.lb.asg_name
}
