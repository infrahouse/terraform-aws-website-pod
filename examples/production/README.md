# Production Example

This example demonstrates a production-ready configuration with monitoring, access logging, and security best practices.

## What This Example Creates

- Application Load Balancer with access logging enabled
- Auto Scaling Group with larger instances (t3.medium)
- CloudWatch alarms for health, latency, and error rate monitoring
- SNS topic for alarm notifications
- Instance profile with application-specific IAM permissions
- Deletion protection enabled
- Vanta compliance tags

## Prerequisites

- AWS CLI configured with appropriate credentials
- Existing VPC with public and private subnets
- Route53 hosted zone
- SSH key pair

## Usage

1. Create a `terraform.tfvars` file:

```hcl
aws_region          = "us-west-2"
environment         = "production"
domain_name         = "app.example.com"
zone_id             = "Z1234567890ABC"
alarm_emails        = ["ops@example.com", "oncall@example.com"]
vpc_id              = "vpc-0123456789abcdef0"
private_subnet_ids  = ["subnet-private1", "subnet-private2"]
public_subnet_ids   = ["subnet-public1", "subnet-public2"]
internet_gateway_id = "igw-0123456789abcdef0"
key_pair_name       = "production-key"
```

2. Apply the configuration:

```bash
terraform init
terraform plan
terraform apply
```

3. **Important**: Confirm the SNS subscription emails to receive alarm notifications.

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| aws_region | AWS region | string | No (default: us-west-2) |
| environment | Environment name | string | No (default: production) |
| domain_name | Domain name for the website | string | Yes |
| zone_id | Route53 hosted zone ID | string | Yes |
| alarm_emails | Email addresses for alarms | list(string) | Yes |
| vpc_id | VPC ID | string | Yes |
| private_subnet_ids | Private subnet IDs | list(string) | Yes |
| public_subnet_ids | Public subnet IDs | list(string) | Yes |
| internet_gateway_id | Internet Gateway ID | string | Yes |
| key_pair_name | SSH key pair name | string | Yes |

## Outputs

| Name | Description |
|------|-------------|
| website_url | URL of the deployed website |
| load_balancer_dns | DNS name of the load balancer |
| load_balancer_arn | ARN of the load balancer |
| asg_name | Name of the Auto Scaling Group |
| alarm_topic_arn | ARN of the SNS topic for alarms |

## Security Features

- **Access Logging**: ALB access logs stored in encrypted S3 bucket
- **Deletion Protection**: Prevents accidental deletion of load balancer
- **Health Monitoring**: Alerts on any unhealthy host
- **Compliance Tags**: Vanta tags for SOC2/HIPAA compliance tracking
