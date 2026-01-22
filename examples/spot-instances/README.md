# Spot Instances Example

This example demonstrates how to use spot instances to reduce EC2 costs by up to 90%.

## How Spot Instances Work

When you set `on_demand_base_capacity`, the Auto Scaling Group will:

1. **Maintain a base of on-demand instances** - These provide guaranteed availability and won't be interrupted
2. **Use spot instances for additional capacity** - These are significantly cheaper but can be interrupted with 2-minute notice

In this example:
- `on_demand_base_capacity = 1` - Always keep 1 on-demand instance
- `asg_min_size = 2` - Minimum 2 instances total
- At minimum capacity: 1 on-demand + 1 spot instance

## Cost Savings

Spot instances typically cost 60-90% less than on-demand instances:

| Instance Type | On-Demand | Spot (typical) | Savings |
|--------------|-----------|----------------|---------|
| t3.small | $0.0208/hr | $0.0062/hr | 70% |
| t3.medium | $0.0416/hr | $0.0125/hr | 70% |
| t3.large | $0.0832/hr | $0.0250/hr | 70% |

## Considerations

**Best for:**
- Non-critical workloads
- Stateless applications
- Development/staging environments
- Batch processing

**Not recommended for:**
- Production workloads requiring 100% availability
- Stateful applications without proper session management
- Time-sensitive processing

## Prerequisites

- AWS CLI configured with appropriate credentials
- Existing VPC with public and private subnets
- Route53 hosted zone
- SSH key pair

## Usage

1. Create a `terraform.tfvars` file:

```hcl
aws_region          = "us-west-2"
environment         = "staging"
zone_id             = "Z1234567890ABC"
vpc_id              = "vpc-0123456789abcdef0"
private_subnet_ids  = ["subnet-private1", "subnet-private2"]
public_subnet_ids   = ["subnet-public1", "subnet-public2"]
internet_gateway_id = "igw-0123456789abcdef0"
key_pair_name       = "staging-key"
```

2. Apply the configuration:

```bash
terraform init
terraform plan
terraform apply
```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| aws_region | AWS region | string | No (default: us-west-2) |
| environment | Environment name | string | No (default: staging) |
| zone_id | Route53 hosted zone ID | string | Yes |
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
| asg_name | Name of the Auto Scaling Group |
