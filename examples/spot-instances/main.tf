# Spot Instances Example
# This example demonstrates how to use spot instances to reduce costs.

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
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"
}

variable "zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EC2 instances"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
}

variable "internet_gateway_id" {
  description = "Internet Gateway ID"
  type        = string
}

variable "key_pair_name" {
  description = "SSH key pair name"
  type        = string
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

# Cloud-init userdata
module "userdata" {
  source  = "infrahouse/cloud-init/aws"
  version = "~> 2.0"

  environment = var.environment
  role        = "webserver"
  packages    = ["nginx"]

  post_runcmd = [
    "systemctl enable nginx",
    "systemctl start nginx"
  ]
}

# Deploy the website module with spot instances
module "website" {
  source = "../../"

  providers = {
    aws     = aws
    aws.dns = aws
  }

  environment  = var.environment
  service_name = "spot-example"

  # Instance configuration
  ami           = data.aws_ami.ubuntu.image_id
  instance_type = "t3.small"

  # Network
  backend_subnets     = var.private_subnet_ids
  subnets             = var.public_subnet_ids
  internet_gateway_id = var.internet_gateway_id
  key_pair_name       = var.key_pair_name

  # DNS
  zone_id       = var.zone_id
  dns_a_records = ["spot-example"]

  # Auto Scaling with spot instances
  asg_min_size = 2
  asg_max_size = 10

  # Enable spot instances:
  # - Keep 1 on-demand instance as a base (for availability)
  # - Use spot instances for additional capacity (cost savings)
  on_demand_base_capacity = 1

  # Application
  userdata = module.userdata.userdata

  tags = {
    Environment = var.environment
    CostCenter  = "spot-savings"
  }
}

output "website_url" {
  description = "URL of the deployed website"
  value       = module.website.dns_name
}

output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = module.website.load_balancer_dns_name
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.website.asg_name
}
