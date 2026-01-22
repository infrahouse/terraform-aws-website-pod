# Configuration Reference

This page documents all configuration options for the terraform-aws-website-pod module.

## Required Variables

These variables must be provided:

| Variable | Type | Description |
|----------|------|-------------|
| `ami` | string | AMI ID for EC2 instances |
| `backend_subnets` | list(string) | Subnet IDs where EC2 instances will run |
| `internet_gateway_id` | string | Internet Gateway ID (ensures IGW exists) |
| `key_pair_name` | string | SSH key pair name for EC2 instances |
| `subnets` | list(string) | Subnet IDs where ALB will be deployed |
| `userdata` | string | Cloud-init userdata for instance provisioning |
| `zone_id` | string | Route53 hosted zone ID for DNS records |

## Instance Configuration

### Basic Settings

```hcl
module "website" {
  # ... required variables ...

  instance_type   = "t3.small"      # EC2 instance type (default: t3.micro)
  root_volume_size = 50             # Root volume size in GB (default: 30)
  environment     = "production"    # Environment name (default: development)
  service_name    = "my-app"        # Service name (default: website)
}
```

### Auto Scaling

```hcl
module "website" {
  # ... required variables ...

  asg_min_size                = 2    # Minimum instances (default: 2)
  asg_max_size                = 10   # Maximum instances (default: 10)
  autoscaling_target_cpu_load = 70   # Target CPU % (default: 60)

  # Instance refresh settings
  min_healthy_percentage      = 100  # % healthy during refresh (default: 100)
  max_instance_lifetime_days  = 14   # Force rotation (default: 30, 0 to disable)

  # Health check settings
  health_check_type           = "ELB"   # EC2 or ELB (default: ELB)
  health_check_grace_period   = 300     # Seconds before health checks (default: 600)
  wait_for_capacity_timeout   = "15m"   # Timeout for healthy instances (default: 20m)
}
```

### Spot Instances

```hcl
module "website" {
  # ... required variables ...

  # Enable spot instances with 1 on-demand base
  on_demand_base_capacity = 1

  # The ASG will maintain at least 1 on-demand instance
  # Additional capacity uses spot instances
}
```

### Lifecycle Hooks

```hcl
module "website" {
  # ... required variables ...

  # Create lifecycle hooks for graceful scaling
  asg_lifecycle_hook_launching    = "app-launching"
  asg_lifecycle_hook_terminating  = "app-terminating"
  asg_lifecycle_hook_heartbeat_timeout = 1800  # 30 minutes (default: 3600)

  # Default action if hook times out
  asg_lifecycle_hook_launching_default_result   = "ABANDON"  # or CONTINUE
  asg_lifecycle_hook_terminating_default_result = "ABANDON"
}
```

## Load Balancer Configuration

### Basic ALB Settings

```hcl
module "website" {
  # ... required variables ...

  alb_name_prefix        = "api"    # Name prefix (default: web)
  alb_idle_timeout       = 120      # Idle timeout seconds (default: 60)
  alb_listener_port      = 8080     # HTTP listener port, redirects to HTTPS on 443 (default: 80)
  enable_deletion_protection = true # Prevent accidental deletion (default: false)
}
```

### Target Group Settings

```hcl
module "website" {
  # ... required variables ...

  target_group_port    = 8080        # Backend port (default: 80)
  target_group_type    = "instance"  # instance, ip, or alb (default: instance)
  stickiness_enabled   = true        # Session stickiness (default: true)

  # Load balancing algorithm
  load_balancing_algorithm_type = "least_outstanding_requests"  # or round_robin (default)

  # Deregistration delay for graceful shutdown
  target_group_deregistration_delay = 30  # seconds (default: 300)
}
```

### Health Checks

```hcl
module "website" {
  # ... required variables ...

  alb_healthcheck_enabled          = true        # Enable health checks (default: true)
  alb_healthcheck_path             = "/health"   # Health check path (default: /index.html)
  alb_healthcheck_port             = 8080        # Health check port (default: 80)
  alb_healthcheck_protocol         = "HTTP"      # HTTP or HTTPS (default: HTTP)
  alb_healthcheck_interval         = 10          # Seconds between checks (default: 5)
  alb_healthcheck_timeout          = 5           # Timeout seconds (default: 4)
  alb_healthcheck_healthy_threshold   = 3        # Consecutive successes (default: 2)
  alb_healthcheck_unhealthy_threshold = 2        # Consecutive failures (default: 2)
  alb_healthcheck_response_code_matcher = "200"  # Expected codes (default: 200-299)
}
```

### Access Logging

```hcl
module "website" {
  # ... required variables ...

  alb_access_log_enabled       = true   # Enable logging (default: false)
  alb_access_log_force_destroy = false  # Delete bucket on destroy (default: false)
}
```

## Security Configuration

### ALB Access Control

```hcl
module "website" {
  # ... required variables ...

  # Restrict ALB access to specific CIDRs
  alb_ingress_cidr_blocks = [
    "10.0.0.0/8",       # Internal network
    "203.0.113.0/24"    # Office IP range
  ]
}
```

### SSH Access

```hcl
module "website" {
  # ... required variables ...

  # Allow SSH from specific CIDR (in addition to VPC)
  ssh_cidr_block = "10.100.0.0/16"  # Management VPC
}
```

### Additional Security Groups

```hcl
module "website" {
  # ... required variables ...

  # Add extra security groups to backend instances
  extra_security_groups_backend = [
    aws_security_group.database_client.id,
    aws_security_group.monitoring_agent.id
  ]
}
```

### Certificate Issuers

```hcl
module "website" {
  # ... required variables ...

  # Allow additional certificate authorities
  certificate_issuers = ["amazon.com", "letsencrypt.org"]
}
```

## DNS Configuration

```hcl
module "website" {
  # ... required variables ...

  dns_a_records = ["", "www", "api"]  # Creates example.com, www.example.com, api.example.com
}
```

## Monitoring Configuration {#monitoring}

### CloudWatch Alarms

```hcl
module "website" {
  # ... required variables ...

  # Email notifications (required to enable alarms)
  alarm_emails = ["ops@example.com", "oncall@example.com"]

  # Or use existing SNS topics
  alarm_topic_arns = [
    "arn:aws:sns:us-west-2:123456789012:pagerduty"
  ]

  # Alarm thresholds
  alarm_unhealthy_host_threshold       = 0      # Alert on any unhealthy host (default: 1)
  alarm_target_response_time_threshold = 2.0    # Latency threshold seconds (default: auto)
  alarm_success_rate_threshold         = 99.5   # Minimum success rate % (default: 99)
  alarm_cpu_utilization_threshold      = 85     # CPU alarm % (default: auto)

  # Alarm timing
  alarm_evaluation_periods  = 3     # Consecutive periods (default: 2)
  alarm_success_rate_period = 300   # Period seconds (default: 300)
}
```

## IAM Configuration

### Instance Profile Permissions

```hcl
data "aws_iam_policy_document" "app_permissions" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::my-bucket/*"]
  }

  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:*:*:secret:my-app/*"]
  }
}

module "website" {
  # ... required variables ...

  instance_profile_permissions = data.aws_iam_policy_document.app_permissions.json
  instance_role_name           = "my-app-role"  # Optional custom role name
}
```

## Compliance Tags (Vanta)

```hcl
module "website" {
  # ... required variables ...

  vanta_owner            = "team@example.com"
  vanta_description      = "Production web application"
  vanta_contains_user_data = true
  vanta_contains_ephi    = false
  vanta_user_data_stored = "User profiles and preferences"

  # Override production environment detection
  vanta_production_environments = ["production", "prod", "live"]
}
```

## Custom Tags

```hcl
module "website" {
  # ... required variables ...

  tags = {
    Project     = "my-project"
    CostCenter  = "engineering"
    ManagedBy   = "terraform"
  }
}
```

## Provider Configuration

```hcl
module "website" {
  providers = {
    aws     = aws.main       # Main AWS provider
    aws.dns = aws.route53    # Provider for Route53 (can be different account)
  }

  # ... other variables ...
}
```