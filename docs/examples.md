# Examples

This page provides common configuration examples for the terraform-aws-website-pod module.

## Basic Web Application

A minimal configuration for a simple web application:

```hcl
module "website" {
  providers = {
    aws     = aws
    aws.dns = aws
  }
  source  = "registry.infrahouse.com/infrahouse/website-pod/aws"
  version = "5.14.0"

  environment         = "production"
  ami                 = data.aws_ami.ubuntu.image_id
  backend_subnets     = module.vpc.private_subnets
  subnets             = module.vpc.public_subnets
  zone_id             = aws_route53_zone.main.zone_id
  dns_a_records       = ["", "www"]
  key_pair_name       = aws_key_pair.deployer.key_name
  userdata            = module.cloud_init.userdata
}
```

## Production Configuration

A full production configuration with monitoring, logging, and security:

```hcl
module "website" {
  providers = {
    aws     = aws
    aws.dns = aws
  }
  source  = "registry.infrahouse.com/infrahouse/website-pod/aws"
  version = "5.14.0"

  # Basic settings
  environment  = "production"
  service_name = "my-app"

  # Instance configuration
  ami            = data.aws_ami.ubuntu.image_id
  instance_type  = "t3.medium"
  root_volume_size = 50

  # Network
  backend_subnets     = module.vpc.private_subnets
  subnets             = module.vpc.public_subnets
  key_pair_name       = aws_key_pair.deployer.key_name

  # DNS
  zone_id       = aws_route53_zone.main.zone_id
  dns_a_records = ["", "www"]

  # Auto Scaling
  asg_min_size                = 2
  asg_max_size                = 20
  autoscaling_target_cpu_load = 60

  # Application
  userdata              = module.cloud_init.userdata
  target_group_port     = 8080
  alb_healthcheck_path  = "/health"

  # Security
  alb_access_log_enabled = true
  enable_deletion_protection = true

  # Monitoring
  alarm_emails = ["ops@example.com", "oncall@example.com"]
  alarm_unhealthy_host_threshold = 0  # Alert on any unhealthy host

  # Compliance
  vanta_owner              = "platform-team@example.com"
  vanta_contains_user_data = true
  vanta_description        = "Production web application"

  tags = {
    Project    = "my-app"
    CostCenter = "engineering"
  }
}
```

## Spot Instances {#spot-instances}

Use spot instances to reduce costs by up to 90%:

```hcl
module "website" {
  providers = {
    aws     = aws
    aws.dns = aws
  }
  source  = "registry.infrahouse.com/infrahouse/website-pod/aws"
  version = "5.14.0"

  # ... required variables ...

  # Enable spot instances
  # Keep 1 on-demand instance as a base, rest will be spot
  on_demand_base_capacity = 1

  # Auto Scaling settings
  asg_min_size = 2   # At least 2 instances
  asg_max_size = 10  # Up to 10 instances

  # The ASG will:
  # - Always maintain 1 on-demand instance
  # - Use spot instances for additional capacity
  # - Automatically replace interrupted spot instances
}
```

## Restricting Access {#restricting-access}

Restrict ALB access to specific IP ranges (internal applications, VPN users, etc.):

```hcl
module "website" {
  providers = {
    aws     = aws
    aws.dns = aws
  }
  source  = "registry.infrahouse.com/infrahouse/website-pod/aws"
  version = "5.14.0"

  # ... required variables ...

  # Only allow access from specific CIDRs
  alb_ingress_cidr_blocks = [
    "10.0.0.0/8",        # Internal corporate network
    "192.168.1.0/24",    # VPN users
    "203.0.113.50/32"    # Office static IP
  ]
}
```

## Cross-Account DNS

When your Route53 zone is in a different AWS account:

```hcl
# Provider for the main account
provider "aws" {
  region = "us-west-2"
}

# Provider for the DNS account
provider "aws" {
  alias  = "dns"
  region = "us-west-2"

  assume_role {
    role_arn = "arn:aws:iam::DNS_ACCOUNT_ID:role/route53-admin"
  }
}

module "website" {
  providers = {
    aws     = aws
    aws.dns = aws.dns  # Use the cross-account provider
  }
  source  = "registry.infrahouse.com/infrahouse/website-pod/aws"
  version = "5.14.0"

  # ... other variables ...
}
```

## Custom Health Checks

Configure health checks for applications with specific requirements:

```hcl
module "website" {
  providers = {
    aws     = aws
    aws.dns = aws
  }
  source  = "registry.infrahouse.com/infrahouse/website-pod/aws"
  version = "5.14.0"

  # ... required variables ...

  # Custom health check configuration
  alb_healthcheck_path     = "/api/health"
  alb_healthcheck_port     = 8080
  alb_healthcheck_protocol = "HTTP"
  alb_healthcheck_interval = 15
  alb_healthcheck_timeout  = 10

  # Require 3 successful checks to be healthy
  alb_healthcheck_healthy_threshold = 3

  # Mark unhealthy after 2 failures
  alb_healthcheck_unhealthy_threshold = 2

  # Accept 200-299 and 301 as healthy
  alb_healthcheck_response_code_matcher = "200-299,301"
}
```

## Session Stickiness

Configure session stickiness for stateful applications:

```hcl
module "website" {
  providers = {
    aws     = aws
    aws.dns = aws
  }
  source  = "registry.infrahouse.com/infrahouse/website-pod/aws"
  version = "5.14.0"

  # ... required variables ...

  # Enable stickiness (default is true)
  stickiness_enabled = true

  # Use least outstanding requests for better load distribution
  # Note: Stickiness still applies after initial assignment
  load_balancing_algorithm_type = "least_outstanding_requests"
}
```

## Lifecycle Hooks

Use lifecycle hooks for graceful deployments:

```hcl
module "website" {
  providers = {
    aws     = aws
    aws.dns = aws
  }
  source  = "registry.infrahouse.com/infrahouse/website-pod/aws"
  version = "5.14.0"

  # ... required variables ...

  # Create lifecycle hooks
  asg_lifecycle_hook_launching   = "app-launching"
  asg_lifecycle_hook_terminating = "app-terminating"

  # Wait up to 30 minutes for hooks to complete
  asg_lifecycle_hook_heartbeat_timeout = 1800

  # Abandon instance if hook fails (safer than CONTINUE)
  asg_lifecycle_hook_launching_default_result   = "ABANDON"
  asg_lifecycle_hook_terminating_default_result = "ABANDON"
}
```

Then use AWS Systems Manager, Lambda, or another service to complete the lifecycle actions.

## Custom Instance Permissions

Grant EC2 instances specific AWS permissions:

```hcl
data "aws_iam_policy_document" "app_permissions" {
  # Access to S3 bucket
  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::my-app-assets",
      "arn:aws:s3:::my-app-assets/*"
    ]
  }

  # Access to Secrets Manager
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:*:*:secret:my-app/*"]
  }

  # Access to Parameter Store
  statement {
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = ["arn:aws:ssm:*:*:parameter/my-app/*"]
  }
}

module "website" {
  providers = {
    aws     = aws
    aws.dns = aws
  }
  source  = "registry.infrahouse.com/infrahouse/website-pod/aws"
  version = "5.14.0"

  # ... required variables ...

  instance_profile_permissions = data.aws_iam_policy_document.app_permissions.json
  instance_role_name           = "my-app-instance-role"
}
```

## PagerDuty/Slack Integration

Send alarms to external services:

```hcl
# Create SNS topic for PagerDuty
resource "aws_sns_topic" "pagerduty" {
  name = "pagerduty-alerts"
}

resource "aws_sns_topic_subscription" "pagerduty" {
  topic_arn = aws_sns_topic.pagerduty.arn
  protocol  = "https"
  endpoint  = "https://events.pagerduty.com/integration/YOUR_INTEGRATION_KEY/enqueue"
}

module "website" {
  providers = {
    aws     = aws
    aws.dns = aws
  }
  source  = "registry.infrahouse.com/infrahouse/website-pod/aws"
  version = "5.14.0"

  # ... required variables ...

  # Send alarms to both email and PagerDuty
  alarm_emails     = ["ops@example.com"]
  alarm_topic_arns = [aws_sns_topic.pagerduty.arn]
}
```

## ECS Integration

Use the module with ECS (disable ASG target group attachment):

```hcl
module "website" {
  providers = {
    aws     = aws
    aws.dns = aws
  }
  source  = "registry.infrahouse.com/infrahouse/website-pod/aws"
  version = "5.14.0"

  # ... required variables ...

  # Disable ASG target group attachment - ECS will manage targets
  attach_target_group_to_asg = false

  # Configure target group for ECS
  target_group_type = "ip"  # ECS Fargate uses IP targets
}

# Then use the target_group_arn output with your ECS service
resource "aws_ecs_service" "app" {
  # ... ECS configuration ...

  load_balancer {
    target_group_arn = module.website.target_group_arn
    container_name   = "app"
    container_port   = 8080
  }
}
```