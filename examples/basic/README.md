# Basic Example

This example demonstrates the minimum configuration required to deploy a web application using the terraform-aws-website-pod module.

## What This Example Creates

- VPC with public and private subnets
- Route53 hosted zone
- Application Load Balancer
- Auto Scaling Group with EC2 instances running nginx
- ACM SSL certificate with automatic validation
- Security groups for ALB and backend instances

## Prerequisites

- AWS CLI configured with appropriate credentials
- SSH key pair (~/.ssh/id_rsa.pub)
- Terraform >= 1.5

## Usage

```bash
terraform init
terraform plan
terraform apply
```

## Inputs

This example uses default values for most variables. See `main.tf` for the configuration.

## Outputs

| Name | Description |
|------|-------------|
| website_url | URL of the deployed website |
| load_balancer_dns | DNS name of the load balancer |

## Notes

- The Route53 zone created in this example uses `example.com`. Replace with your actual domain.
- For production use, consider enabling monitoring and access logging (see the production example).
