# Configuration Reference

This page documents all configuration options for the terraform-aws-website-pod module.

## Required Variables

These variables must be provided:

| Variable | Type | Description |
|----------|------|-------------|
| `ami` | string | AMI ID for EC2 instances |
| `backend_subnets` | list(string) | Subnet IDs where EC2 instances will run |
| `key_pair_name` | string | SSH key pair name for EC2 instances |
| `replication_region` | string | Region for cross-region replication of the access-log bucket |
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
  autoscaling_target_cpu_load = 70   # Target CPU % (default: 60; null to disable the policy)

  # Instance refresh settings
  min_healthy_percentage      = 100  # % healthy during refresh (default: 100)
  max_instance_lifetime_days  = 14   # Force rotation (default: 30, 0 to disable)

  # Health check settings
  health_check_type           = "ELB"   # EC2 or ELB (default: ELB)
  health_check_grace_period   = 300     # Seconds before health checks (default: 600)
  wait_for_capacity_timeout   = "15m"   # Timeout for healthy instances (default: 20m)
}
```

Set `autoscaling_target_cpu_load = null` to skip creating the host-CPU target-tracking
policy entirely. Do this when instance count is driven by another controller — e.g. an
ECS capacity provider's managed scaling — where a second ASG policy on the same
`DesiredCapacity` lever would conflict. The high-CPU CloudWatch alarm is still created
for Vanta compliance; when the target is `null` its threshold falls back to a fixed 90%
(instead of target + 30%).

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

### Capacity Reservations (ODCR)

Bind the ASG's launch template to an On-Demand Capacity Reservation (ODCR) so
instances launch into pre-reserved capacity. This guarantees a service can always
get the instances it needs — useful for scarce instance types (e.g. GPU hosts like
`g5.2xlarge`) where on-demand launches may otherwise fail with an
`InsufficientInstanceCapacity` error.

Target a single reservation by ID:

```hcl
module "website" {
  # ... required variables ...

  instance_type           = "g5.2xlarge"
  capacity_reservation_id = "cr-0123456789abcdef0"

  # Instances launch into this reservation (instance_match_criteria = targeted).
}
```

Or target a group of reservations by resource-group ARN (lets you pool several
reservations, e.g. across AZs, behind one identifier):

```hcl
module "website" {
  # ... required variables ...

  capacity_reservation_resource_group_arn =
    "arn:aws:resource-groups:us-west-2:123456789012:group/my-odcr-group"
}
```

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `capacity_reservation_id` | string | `null` | Single ODCR to target |
| `capacity_reservation_resource_group_arn` | string | `null` | Reservation resource-group ARN to target |

**Notes:**

- The two variables are **mutually exclusive** — set at most one. Setting both fails validation.
- When neither is set (the default), the launch template has no capacity-reservation
  block and behaves exactly as before, so existing deployments are unaffected.
- Only the reservation *target* is set (not `capacity_reservation_preference`), so AWS
  uses `instance_match_criteria = targeted`: only instances that explicitly target the
  reservation consume it.
- For an ECS-capacity-provider-managed ASG driving GPU capacity, pair this with
  `autoscaling_target_cpu_load = null` (see [Auto Scaling](#auto-scaling)) so ECS
  managed scaling is the sole controller of instance count.

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

Access logging is always enabled (encrypted, versioned, cross-region-replicated bucket).
Tune retention and teardown:

```hcl
module "website" {
  # ... required variables ...

  replication_region             = "us-east-1"  # Replica bucket region (required)
  alb_access_log_expiration_days = 365           # Retention (default: 365)
  alb_access_log_force_destroy   = false         # Delete bucket on destroy (default: false)
}
```

### Access Log Querying with Athena

```hcl
module "website" {
  # ... required variables ...

  alb_access_log_athena_enabled = true   # Creates Athena querying stack
}
```

This creates a Glue catalog (database + table), Athena workgroup, and S3 results bucket.
Query your logs from the Athena console using SQL:

```sql
SELECT time, client_ip, request_url, elb_status_code
FROM <service_name>_alb_access_logs
WHERE elb_status_code >= 500
ORDER BY time DESC
LIMIT 100;
```

| Output | Description |
|--------|-------------|
| `alb_access_log_glue_database` | Glue catalog database name |
| `alb_access_log_glue_table` | Glue catalog table name |
| `athena_workgroup` | Athena workgroup name |
| `athena_results_bucket` | S3 bucket for query results |

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

### Deferring Inspector Findings Until Patched

Amazon Inspector reports findings against a freshly launched instance before
`unattended-upgrades` has run. The finding closes on the next upgrade, but it has already
reopened its vulnerability group by then, which breaks the remediation SLA.

`defer_inspector_findings_until_patched` makes the ASG tag instances with
`InspectorEc2Exclusion` at launch, so Inspector creates no findings until Puppet's
`profile::boot_security_upgrade` applies pending security updates and deletes the tag.
(The instance is still scanned while excluded — only finding creation is suppressed.)

```hcl
locals {
  asg_name = "my-website"
}

module "website" {
  # ... required variables ...

  asg_name                               = local.asg_name
  defer_inspector_findings_until_patched = true
  instance_profile_permissions           = data.aws_iam_policy_document.instance_permissions.json
}

# The module supplies the tag; the caller supplies the permission to remove it.
data "aws_iam_policy_document" "instance_permissions" {
  statement {
    actions   = ["ec2:DeleteTags"]
    resources = ["arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:instance/*"]
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "aws:TagKeys"
      values   = ["InspectorEc2Exclusion"]
    }
    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/aws:autoscaling:groupName"
      values   = [local.asg_name]
    }
  }
}
```

Before enabling it:

- **The tag is fail-open.** Only `profile::boot_security_upgrade` removes it. Instances
  whose Puppet role does not include that profile — or whose instance profile lacks
  `ec2:DeleteTags` — stay invisible to Inspector for their entire life, which is worse
  than never tagging. That is why the default is `false`.
- **Scope the IAM grant with a value known before the ASG exists** — your own
  `local.asg_name`, not the module's `asg_name` output. The output would order the grant
  after the ASG has already begun launching tagged instances.
- **Flipping the flag triggers a rolling instance refresh.** The ASG's `instance_refresh`
  is triggered on `tag`, so this is not a no-op apply.
- **Findings take time to reappear.** Scanning resumes as soon as the tag is removed, but
  findings show up after roughly 1.5–2 hours of running time. Measure with
  `firstObservedAt`, not `lastScannedAt`.

To confirm the tag was actually set at launch, read it from instance metadata (the launch
template enables `instance_metadata_tags`), rather than trusting `delete-tags`, which
succeeds whether or not the key was present:

```bash
curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/tags/instance/InspectorEc2Exclusion
```

## DNS Configuration

### Basic DNS Records

```hcl
module "website" {
  # ... required variables ...

  dns_a_records = ["", "www", "api"]  # Creates example.com, www.example.com, api.example.com
}
```

### Weighted Routing for Zero-Downtime Migrations

Route53 weighted routing enables gradual traffic shifting between services, perfect for:
- Blue/green deployments
- Zero-downtime service migrations
- A/B testing with traffic percentages

```hcl
# Old service (being deprecated) - receives 10% of traffic
module "website_old" {
  # ... required variables ...

  dns_routing_policy = "weighted"
  dns_set_identifier = "legacy-service"
  dns_weight         = 10
}

# New service (receiving traffic) - receives 90% of traffic
module "website_new" {
  # ... required variables ...

  dns_routing_policy = "weighted"
  dns_set_identifier = "new-service"
  dns_weight         = 90
}
```

**Migration workflow:**

1. Deploy new service with `dns_weight = 0` (no traffic)
2. Convert existing service to weighted with `dns_weight = 100`
3. Gradually shift traffic: 90/10 → 50/50 → 10/90 → 0/100
4. Remove old service

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `dns_routing_policy` | string | `"simple"` | `"simple"` or `"weighted"` |
| `dns_weight` | number | `100` | Weight for weighted routing (0-255) |
| `dns_set_identifier` | string | `null` | Unique identifier (required for weighted) |

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
