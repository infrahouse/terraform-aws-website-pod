# terraform-aws-website-pod

A production-ready Terraform module for deploying web applications on AWS with Application Load Balancer, Auto Scaling Group, and automatic SSL certificate management.

## Overview

This module creates all the infrastructure needed to run a scalable, secure web application on AWS:

- **Application Load Balancer (ALB)** - Distributes traffic across multiple instances with automatic HTTP to HTTPS redirect
- **Auto Scaling Group (ASG)** - Automatically scales instances based on CPU utilization
- **ACM SSL Certificate** - Automatically provisions and validates SSL certificates via DNS
- **Route53 DNS Records** - Creates A records and CAA records for your domain
- **CloudWatch Alarms** - Monitors health, latency, error rates, and CPU utilization
- **Security Groups** - Configurable ingress rules for ALB and backend instances

## Features

- **Zero-downtime deployments** with instance refresh and lifecycle hooks
- **Automatic SSL/TLS** certificate provisioning and renewal via AWS ACM
- **Cost optimization** with spot instance support (up to 90% savings)
- **Security best practices** including CAA records, configurable access controls, and compliance support
- **Comprehensive monitoring** with CloudWatch alarms for CPU, latency, errors, and unhealthy hosts
- **Session stickiness** for stateful applications
- **ALB access logging** to S3 for security investigations and compliance

## Quick Start

```hcl
module "website" {
  providers = {
    aws     = aws
    aws.dns = aws
  }
  source  = "registry.infrahouse.com/infrahouse/website-pod/aws"
  version = "5.17.0"

  environment         = "production"
  ami                 = data.aws_ami.ubuntu.image_id
  backend_subnets     = module.vpc.private_subnet_ids
  subnets             = module.vpc.public_subnet_ids
  zone_id             = aws_route53_zone.main.zone_id
  dns_a_records       = ["", "www"]
  key_pair_name       = aws_key_pair.deployer.key_name
  userdata            = module.cloud_init.userdata

  # Enable monitoring (recommended)
  alarm_emails = ["ops@example.com"]

  # Enable access logging (recommended for production)
  alb_access_log_enabled = true
}
```

## Requirements

| Name | Version |
|------|---------|
| Terraform | ~> 1.5 |
| AWS Provider | >= 5.11, < 7.0 |

## Getting Help

- [Getting Started Guide](getting-started.md) - First deployment walkthrough
- [Architecture](architecture.md) - How the module works
- [Configuration Reference](configuration.md) - All variables explained
- [Examples](examples.md) - Common use cases
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
- [Changelog](changelog.md) - Version history

## Links

- [GitHub Repository](https://github.com/infrahouse/terraform-aws-website-pod)
- [Terraform Registry](https://registry.terraform.io/modules/infrahouse/website-pod/aws/latest)
- [Report Issues](https://github.com/infrahouse/terraform-aws-website-pod/issues)