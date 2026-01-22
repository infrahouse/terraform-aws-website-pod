# Production Example
# This example demonstrates a production-ready configuration with monitoring,
# access logging, and security best practices.

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
  default     = "production"
}

variable "domain_name" {
  description = "Domain name for the website"
  type        = string
}

variable "zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

variable "alarm_emails" {
  description = "Email addresses for alarm notifications"
  type        = list(string)
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

# IAM policy for application-specific permissions
data "aws_iam_policy_document" "app_permissions" {
  # Access to application secrets
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.environment}/*"]
  }

  # Access to application S3 bucket
  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.environment}-app-assets",
      "arn:aws:s3:::${var.environment}-app-assets/*"
    ]
  }

  # CloudWatch Logs
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = ["arn:aws:logs:${var.aws_region}:*:log-group:/app/${var.environment}/*"]
  }
}

# Cloud-init userdata for production
module "userdata" {
  source  = "infrahouse/cloud-init/aws"
  version = "~> 2.0"

  environment = var.environment
  role        = "webserver"
  packages = [
    "nginx",
    "awscli",
    "jq"
  ]

  custom_facts = {
    "app_environment" = var.environment
    "app_domain"      = var.domain_name
  }

  post_runcmd = [
    "systemctl enable nginx",
    "systemctl start nginx",
    "echo 'Production deployment complete' >> /var/log/cloud-init-output.log"
  ]
}

# Deploy the website module with production settings
module "website" {
  source = "../../"

  providers = {
    aws     = aws
    aws.dns = aws
  }

  # Basic settings
  environment  = var.environment
  service_name = "production-app"

  # Instance configuration
  ami              = data.aws_ami.ubuntu.image_id
  instance_type    = "t3.medium"
  root_volume_size = 50

  # Network
  backend_subnets     = var.private_subnet_ids
  subnets             = var.public_subnet_ids
  internet_gateway_id = var.internet_gateway_id
  key_pair_name       = var.key_pair_name

  # DNS
  zone_id       = var.zone_id
  dns_a_records = ["", "www"]

  # Auto Scaling
  asg_min_size                = 2
  asg_max_size                = 20
  autoscaling_target_cpu_load = 60
  max_instance_lifetime_days  = 14

  # Application
  userdata             = module.userdata.userdata
  target_group_port    = 80
  alb_healthcheck_path = "/health"

  # Security
  alb_access_log_enabled     = true
  enable_deletion_protection = true

  # Instance permissions
  instance_profile_permissions = data.aws_iam_policy_document.app_permissions.json

  # Monitoring
  alarm_emails                   = var.alarm_emails
  alarm_unhealthy_host_threshold = 0 # Alert on any unhealthy host

  # Compliance tags
  vanta_owner              = "platform-team@example.com"
  vanta_contains_user_data = true
  vanta_description        = "Production web application"

  tags = {
    Environment = var.environment
    Project     = "production-app"
    ManagedBy   = "terraform"
  }
}

output "website_url" {
  description = "URL of the deployed website"
  value       = "https://${var.domain_name}"
}

output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = module.website.load_balancer_dns_name
}

output "load_balancer_arn" {
  description = "ARN of the load balancer"
  value       = module.website.load_balancer_arn
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.website.asg_name
}

output "alarm_topic_arn" {
  description = "ARN of the SNS topic for alarms"
  value       = module.website.alarm_sns_topic_arn
}
