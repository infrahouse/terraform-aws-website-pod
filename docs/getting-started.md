# Getting Started

This guide walks you through deploying your first web application using the terraform-aws-website-pod module.

## Prerequisites

Before you begin, ensure you have:

1. **Terraform** >= 1.5 installed
2. **AWS CLI** configured with appropriate credentials
3. **An AWS account** with permissions to create:
    - EC2 instances, Auto Scaling Groups, Launch Templates
    - Application Load Balancers, Target Groups
    - ACM Certificates
    - Route53 DNS records
    - S3 buckets (for access logs)
    - IAM roles and policies
    - Security Groups
    - CloudWatch Alarms and SNS Topics
4. **A Route53 hosted zone** for your domain

## Step 1: Set Up Your VPC

The module requires an existing VPC with public and private subnets. You can use the [terraform-aws-service-network](https://registry.terraform.io/modules/infrahouse/service-network/aws/latest) module:

```hcl
module "vpc" {
  source  = "infrahouse/service-network/aws"
  version = "~> 3.0"

  service_name          = "my-website"
  vpc_cidr_block        = "10.0.0.0/16"
  management_cidr_block = "10.0.0.0/16"  # Set to your management VPC CIDR

  subnets = [
    # Public subnets (for ALB)
    {
      cidr                    = "10.0.101.0/24"
      availability-zone       = "us-west-2a"
      map_public_ip_on_launch = true
      create_nat              = true
    },
    {
      cidr                    = "10.0.102.0/24"
      availability-zone       = "us-west-2b"
      map_public_ip_on_launch = true
    },
    # Private subnets (for EC2 instances)
    {
      cidr              = "10.0.1.0/24"
      availability-zone = "us-west-2a"
      forward_to        = "10.0.101.0/24"
    },
    {
      cidr              = "10.0.2.0/24"
      availability-zone = "us-west-2b"
      forward_to        = "10.0.101.0/24"
    }
  ]
}
```

## Step 2: Create User Data

The module requires cloud-init userdata to provision your EC2 instances. You can use the [terraform-aws-cloud-init](https://registry.terraform.io/modules/infrahouse/cloud-init/aws/latest) module:

```hcl
module "userdata" {
  source  = "infrahouse/cloud-init/aws"
  version = "~> 1.0"

  packages = ["nginx"]

  # Add your application setup here
  runcmd = [
    "systemctl enable nginx",
    "systemctl start nginx"
  ]
}
```

## Step 3: Deploy the Website Module

Now you can deploy the website module:

```hcl
module "website" {
  providers = {
    aws     = aws
    aws.dns = aws
  }
  source  = "registry.infrahouse.com/infrahouse/website-pod/aws"
  version = "5.15.0"

  # Required variables
  environment         = "production"
  ami                 = data.aws_ami.ubuntu.image_id
  backend_subnets     = module.vpc.subnet_private_ids
  subnets             = module.vpc.subnet_public_ids
  zone_id             = aws_route53_zone.main.zone_id
  dns_a_records       = ["", "www"]
  key_pair_name       = aws_key_pair.deployer.key_name
  userdata            = module.userdata.userdata

  # Recommended settings
  alarm_emails           = ["ops@example.com"]
  alb_access_log_enabled = true
}

# Get the latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}
```

## Step 4: Configure Providers

The module requires two AWS providers - one for general resources and one for Route53:

```hcl
provider "aws" {
  region = "us-west-2"
}

# If your Route53 zone is in the same account/region:
provider "aws" {
  alias  = "dns"
  region = "us-west-2"
}
```

If your Route53 zone is in a different account:

```hcl
provider "aws" {
  alias  = "dns"
  region = "us-west-2"
  assume_role {
    role_arn = "arn:aws:iam::DNS_ACCOUNT_ID:role/route53-admin"
  }
}
```

## Step 5: Apply the Configuration

```bash
terraform init
terraform plan
terraform apply
```

The deployment typically takes 10-15 minutes as it waits for:
- ACM certificate validation
- EC2 instances to become healthy
- DNS propagation

## Step 6: Verify the Deployment

After deployment:

1. **Check the outputs:**
   ```bash
   terraform output dns_name
   terraform output load_balancer_dns_name
   ```

2. **Verify SSL certificate:**
   ```bash
   curl -I https://your-domain.com
   ```

3. **Confirm email subscriptions:**
   Check your email for SNS subscription confirmations and click the links to enable alarm notifications.

## Next Steps

- [Configure monitoring and alarms](configuration.md#monitoring)
- [Enable spot instances for cost savings](examples.md#spot-instances)
- [Set up access restrictions](examples.md#restricting-access)
- [Review the architecture](architecture.md)