# Weighted Routing Example
#
# This example demonstrates how to use Route53 weighted routing for zero-downtime
# migrations between services. This is useful for:
# - Blue/green deployments
# - Gradual traffic migration between services
# - A/B testing with traffic percentages
#
# Migration workflow:
# 1. Deploy new service with dns_weight = 0 (no traffic)
# 2. Convert existing service to weighted with dns_weight = 100
# 3. Gradually shift traffic: 90/10 -> 50/50 -> 10/90 -> 0/100
# 4. Remove old service

terraform {
  required_version = "~> 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.11, < 7.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

# Get the latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Create a simple VPC for the example
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "weighted-routing-example-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

# Create Route53 zone (or use existing one)
resource "aws_route53_zone" "example" {
  name = "example.com"
}

# Create SSH key pair
# IMPORTANT: In production, provide your own SSH public key
# This is a placeholder for example purposes only
variable "ssh_public_key" {
  description = "SSH public key for EC2 instances"
  type        = string
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC... example@example.com"
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = var.ssh_public_key
}

# Simple cloud-init userdata for legacy service
module "userdata_legacy" {
  source  = "infrahouse/cloud-init/aws"
  version = "~> 2.0"

  environment = "production"
  role        = "webserver_legacy"
  packages    = ["nginx"]

  post_runcmd = [
    "echo 'Legacy Service v1' > /var/www/html/index.html",
    "systemctl enable nginx",
    "systemctl start nginx"
  ]
}

# Simple cloud-init userdata for new service
module "userdata_new" {
  source  = "infrahouse/cloud-init/aws"
  version = "~> 2.0"

  environment = "production"
  role        = "webserver_new"
  packages    = ["nginx"]

  post_runcmd = [
    "echo 'New Service v2' > /var/www/html/index.html",
    "systemctl enable nginx",
    "systemctl start nginx"
  ]
}

# -----------------------------------------------------------------------------
# Legacy Service - Being deprecated, receives 10% of traffic
# -----------------------------------------------------------------------------
module "website_legacy" {
  source = "../../"

  providers = {
    aws     = aws
    aws.dns = aws
  }

  environment         = "production"
  service_name        = "website-legacy"
  ami                 = data.aws_ami.ubuntu.image_id
  backend_subnets     = module.vpc.private_subnets
  subnets             = module.vpc.public_subnets
  zone_id             = aws_route53_zone.example.zone_id
  dns_a_records       = ["", "www"]
  internet_gateway_id = module.vpc.igw_id
  key_pair_name       = aws_key_pair.deployer.key_name
  userdata            = module.userdata_legacy.userdata

  # Weighted routing configuration - 10% of traffic
  dns_routing_policy = "weighted"
  dns_set_identifier = "legacy-v1"
  dns_weight         = 10
}

# -----------------------------------------------------------------------------
# New Service - Primary service, receives 90% of traffic
# -----------------------------------------------------------------------------
module "website_new" {
  source = "../../"

  providers = {
    aws     = aws
    aws.dns = aws
  }

  environment         = "production"
  service_name        = "website-new"
  ami                 = data.aws_ami.ubuntu.image_id
  backend_subnets     = module.vpc.private_subnets
  subnets             = module.vpc.public_subnets
  zone_id             = aws_route53_zone.example.zone_id
  dns_a_records       = ["", "www"]
  internet_gateway_id = module.vpc.igw_id
  key_pair_name       = aws_key_pair.deployer.key_name
  userdata            = module.userdata_new.userdata

  # Weighted routing configuration - 90% of traffic
  dns_routing_policy = "weighted"
  dns_set_identifier = "new-v2"
  dns_weight         = 90
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "website_url" {
  description = "URL of the deployed website"
  value       = "https://${aws_route53_zone.example.name}"
}

output "legacy_load_balancer_dns" {
  description = "DNS name of the legacy service load balancer"
  value       = module.website_legacy.load_balancer_dns_name
}

output "new_load_balancer_dns" {
  description = "DNS name of the new service load balancer"
  value       = module.website_new.load_balancer_dns_name
}

output "traffic_distribution" {
  description = "Current traffic distribution between services"
  value = {
    legacy_service = "10%"
    new_service    = "90%"
  }
}