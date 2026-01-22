# Basic Example
# This example demonstrates the minimum configuration required to deploy a web application.

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

  name = "website-example-vpc"
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
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

# Simple cloud-init userdata
module "userdata" {
  source  = "infrahouse/cloud-init/aws"
  version = "~> 2.0"

  environment = "development"
  role        = "webserver"
  packages    = ["nginx"]

  post_runcmd = [
    "systemctl enable nginx",
    "systemctl start nginx"
  ]
}

# Deploy the website module
module "website" {
  source = "../../"

  providers = {
    aws     = aws
    aws.dns = aws
  }

  environment         = "development"
  ami                 = data.aws_ami.ubuntu.image_id
  backend_subnets     = module.vpc.private_subnets
  subnets             = module.vpc.public_subnets
  zone_id             = aws_route53_zone.example.zone_id
  dns_a_records       = ["", "www"]
  internet_gateway_id = module.vpc.igw_id
  key_pair_name       = aws_key_pair.deployer.key_name
  userdata            = module.userdata.userdata
}

output "website_url" {
  description = "URL of the deployed website"
  value       = "https://${aws_route53_zone.example.name}"
}

output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = module.website.load_balancer_dns_name
}
