output "network_subnet_public_ids" {
  value = module.network.subnet_public_ids
}

output "network_subnet_private_ids" {
  value = module.network.subnet_private_ids
}

output "network_subnet_all_ids" {
  value = module.network.subnet_all_ids
}

output "network_vpc_cidr_block" {
  value = module.network.vpc_cidr_block
}
