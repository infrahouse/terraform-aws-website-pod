variable "alb_access_log_enabled" {
  description = <<-EOF
    Whether to enable ALB access logging to S3.

    **Security Best Practice:** Enabling access logs is recommended for:
    - Security investigations and incident response
    - Debugging production issues
    - Compliance requirements (SOC2, HIPAA, PCI-DSS)
    - AWS Well-Architected Framework best practices

    When enabled, creates an encrypted, versioned S3 bucket for access logs.
    Storage costs are minimal compared to security and operational benefits.

    **Note:** In v6.0.0, this will default to `true` (enabled by default).
    See UPGRADE-6.0.md for details.
  EOF
  type        = bool
  default     = false
}

variable "alb_access_log_force_destroy" {
  description = "Destroy S3 bucket with access logs even if non-empty"
  type        = bool
  default     = false
}

variable "alb_healthcheck_enabled" {
  description = "Whether health checks are enabled."
  type        = bool
  default     = true
}
variable "alb_healthcheck_path" {
  description = "Path on the webserver that the elb will check to determine whether the instance is healthy or not"
  type        = string
  default     = "/index.html"
}

variable "alb_healthcheck_port" {
  description = "Port of the webserver that the elb will check to determine whether the instance is healthy or not"
  type        = any
  default     = 80
}

variable "alb_healthcheck_protocol" {
  description = "Protocol to use with the webserver that the elb will check to determine whether the instance is healthy or not"
  type        = string
  default     = "HTTP"

  validation {
    condition     = contains(["HTTP", "HTTPS"], var.alb_healthcheck_protocol)
    error_message = "alb_healthcheck_protocol must be either 'HTTP' or 'HTTPS'."
  }
}

variable "alb_healthcheck_healthy_threshold" {
  description = "Number of times the host have to pass the test to be considered healthy"
  type        = number
  default     = 2

  validation {
    condition     = var.alb_healthcheck_healthy_threshold >= 2 && var.alb_healthcheck_healthy_threshold <= 10
    error_message = "Healthy threshold must be between 2 and 10."
  }
}

variable "alb_healthcheck_uhealthy_threshold" {
  description = <<-EOF
    ⚠️  DEPRECATED - Contains typo, use 'alb_healthcheck_unhealthy_threshold' instead.
    This variable will be removed in v6.0.0. See deprecations.tf for details.
    Number of times the host must fail the test to be considered unhealthy.
  EOF
  type        = number
  default     = null
}

variable "alb_healthcheck_unhealthy_threshold" {
  description = "Number of consecutive health check failures required before considering the target unhealthy"
  type        = number
  default     = 2

  validation {
    condition     = var.alb_healthcheck_unhealthy_threshold >= 2 && var.alb_healthcheck_unhealthy_threshold <= 10
    error_message = "Unhealthy threshold must be between 2 and 10."
  }
}

variable "alb_healthcheck_interval" {
  description = "Number of seconds between checks"
  type        = number
  default     = 5

  validation {
    condition     = var.alb_healthcheck_interval >= 5 && var.alb_healthcheck_interval <= 300
    error_message = "Health check interval must be between 5 and 300 seconds."
  }
}

variable "alb_healthcheck_timeout" {
  description = "Number of seconds to timeout a check"
  type        = number
  default     = 4

  validation {
    condition     = var.alb_healthcheck_timeout >= 2 && var.alb_healthcheck_timeout <= 120
    error_message = "Health check timeout must be between 2 and 120 seconds."
  }
}

variable "alb_healthcheck_response_code_matcher" {
  description = "Range of http return codes that can match"
  type        = string
  default     = "200-299"
}
variable "alb_idle_timeout" {
  description = "The time in seconds that the connection is allowed to be idle."
  type        = number
  default     = 60
}

variable "alb_listener_port" {
  description = "TCP port that a load balancer listens to to serve client HTTP requests. The load balancer redirects this port to 443 and HTTPS."
  type        = number
  default     = 80
}

variable "alb_name_prefix" {
  description = "Name prefix for the load balancer"
  type        = string
  default     = "web"
}

variable "alb_ingress_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the ALB. Defaults to allow all (0.0.0.0/0)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ami" {
  description = "Image for EC2 instances"
  type        = string
}

variable "assume_dns" {
  description = "If True, create DNS records provided by var.dns_a_records."
  type        = bool
  default     = true
}

variable "min_healthy_percentage" {
  description = "Amount of capacity in the Auto Scaling group that must remain healthy during an instance refresh to allow the operation to continue, as a percentage of the desired capacity of the Auto Scaling group."
  type        = number
  default     = 100
}

variable "asg_lifecycle_hook_initial" {
  description = <<-EOF
    Name for an initial LAUNCHING lifecycle hook configured via the initial_lifecycle_hook
    block in the ASG. This hook is evaluated during ASG creation.
    Only one initial hook is allowed per ASG.

    Use this for simple lifecycle hooks that don't require additional configuration.
  EOF
  type        = string
  default     = null
}

variable "asg_lifecycle_hook_launching" {
  description = <<-EOF
    Name for a LAUNCHING lifecycle hook configured via a separate
    aws_autoscaling_lifecycle_hook resource. This allows for more complex configurations
    and can be created after the ASG exists.

    Use this if you need to attach SNS notifications or additional settings to the lifecycle hook.
  EOF
  type        = string
  default     = null
}

variable "asg_lifecycle_hook_launching_default_result" {
  description = "Default result for launching lifecycle hook."
  type        = string
  default     = "ABANDON"
}

variable "asg_lifecycle_hook_terminating" {
  description = "Create a TERMINATING lifecycle hook with this name."
  type        = string
  default     = null
}

variable "asg_lifecycle_hook_terminating_default_result" {
  description = "Default result for terminating lifecycle hook."
  type        = string
  default     = "ABANDON"
}

variable "asg_lifecycle_hook_heartbeat_timeout" {
  description = "How much time in seconds to wait until the hook is completed before proceeding with the default action."
  type        = number
  default     = 3600
}


variable "asg_min_elb_capacity" {
  description = "Terraform will wait until this many EC2 instances in the autoscaling group become healthy. By default, it's equal to var.asg_min_size."
  type        = number
  default     = null
}

variable "asg_min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 10
}
variable "asg_min_healthy_percentage" {
  description = "Specifies the lower limit on the number of instances that must be in the InService state with a healthy status during an instance replacement activity."
  type        = number
  default     = 100
}

variable "asg_max_healthy_percentage" {
  description = "Specifies the upper limit on the number of instances that are in the InService or Pending state with a healthy status during an instance replacement activity."
  type        = number
  default     = 200

}

variable "asg_name" {
  description = "Autoscaling group name, if provided."
  type        = string
  default     = null
}

variable "asg_scale_in_protected_instances" {
  description = "Behavior when encountering instances protected from scale in are found. Available behaviors are Refresh, Ignore, and Wait."
  type        = string
  default     = "Ignore"

  validation {
    condition     = contains(["Refresh", "Ignore", "Wait"], var.asg_scale_in_protected_instances)
    error_message = "asg_scale_in_protected_instances must be one of: Refresh, Ignore, Wait."
  }
}

variable "asg_default_cooldown" {
  description = <<-EOF
    Amount of time, in seconds, after a scaling activity completes before another
    scaling activity can start. This prevents rapid scale-in/scale-out cycles.
  EOF
  type        = number
  default     = 300

  validation {
    condition     = var.asg_default_cooldown >= 0 && var.asg_default_cooldown <= 3600
    error_message = "asg_default_cooldown must be between 0 and 3600 seconds."
  }
}

variable "asg_enabled_metrics" {
  description = <<-EOF
    List of ASG metrics to enable for CloudWatch monitoring.
    Set to empty list to disable metrics collection.

    Available metrics:
    - GroupDesiredCapacity
    - GroupInServiceInstances
    - GroupPendingInstances
    - GroupTerminatingInstances
    - GroupTotalInstances
    - GroupMinSize
    - GroupMaxSize
    - GroupInServiceCapacity
    - GroupPendingCapacity
    - GroupStandbyCapacity
    - GroupStandbyInstances
    - GroupTerminatingCapacity
    - GroupTotalCapacity
    - WarmPoolDesiredCapacity
    - WarmPoolWarmedCapacity
    - WarmPoolPendingCapacity
    - WarmPoolTerminatingCapacity
    - WarmPoolTotalCapacity
    - WarmPoolMinSize
    - GroupAndWarmPoolDesiredCapacity
    - GroupAndWarmPoolTotalCapacity
  EOF
  type        = list(string)
  default = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]
}

variable "autoscaling_target_cpu_load" {
  description = "Target CPU load for autoscaling"
  default     = 60
  type        = number
}

variable "backend_subnets" {
  description = "Subnet ids where EC2 instances should be present"
  type        = list(string)
}

# "A" records in a hosted zone, specified by zone_id
# If the zone is infrahouse.com and the "A" records ["www"], then the module
# will create records (and a certificate for):
# - www.infrahouse.com
# To create the A record for infrahouse.com, pass an empty string:
# ["", "www"]
# If we pass A records as ["something"] then the module
# will create the "A" record something.infrahouse.com
variable "dns_a_records" {
  description = "List of A records in the zone_id that will resolve to the ALB dns name."
  type        = list(string)
  default     = [""]
}

variable "enable_deletion_protection" {
  description = "Prevent load balancer from destroying"
  type        = bool
  default     = false
}

variable "environment" {
  description = "Name of environment"
  type        = string
  default     = "development"
}

variable "extra_security_groups_backend" {
  description = "A list of security group ids to assign to backend instances"
  type        = list(string)
  default     = []
}

variable "instance_role_name" {
  description = "If specified, the instance profile role will have this name. Otherwise, the role name will be generated."
  type        = string
  default     = null
}

variable "instance_profile_permissions" {
  description = <<-EOF
    A JSON policy document to attach to the instance profile.
    This should be the output of an aws_iam_policy_document data source.

    Example:
      instance_profile_permissions = data.aws_iam_policy_document.my_policy.json

    If not specified, defaults to a minimal policy allowing sts:GetCallerIdentity.
  EOF
  type        = string
  default     = null
}


variable "instance_type" {
  description = "EC2 instances type"
  type        = string
  default     = "t3.micro"
}

variable "internet_gateway_id" { # tflint-ignore: terraform_unused_declarations
  description = "Not used, but AWS Internet Gateway must be present. Ensure by passing its id."
  type        = string
  default     = null
}

variable "health_check_grace_period" {
  description = "ASG will wait up to this number of seconds for instance to become healthy"
  type        = number
  default     = 600
}

variable "health_check_type" {
  # Good summary
  # https://stackoverflow.com/questions/42466157/whats-the-difference-between-elb-health-check-and-ec2-health-check
  description = "Type of healthcheck the ASG uses. Can be EC2 or ELB."
  type        = string
  default     = "ELB"

  validation {
    condition     = contains(["EC2", "ELB"], var.health_check_type)
    error_message = "health_check_type must be either 'EC2' or 'ELB'."
  }
}

variable "key_pair_name" {
  description = "SSH keypair name to be deployed in EC2 instances"
  type        = string
}

variable "max_instance_lifetime_days" {
  description = "The maximum amount of time, in _days_, that an instance can be in service, values must be either equal to 0 or between 7 and 365 days."
  type        = number
  default     = 30

  validation {
    condition     = var.max_instance_lifetime_days == 0 || (var.max_instance_lifetime_days >= 7 && var.max_instance_lifetime_days <= 365)
    error_message = "max_instance_lifetime_days must be 0 (unlimited) or between 7 and 365 days."
  }
}

variable "protect_from_scale_in" {
  description = "Whether newly launched instances are automatically protected from termination by Amazon EC2 Auto Scaling when scaling in."
  type        = bool
  default     = false
}

variable "root_volume_size" {
  description = "Root volume size in EC2 instance in Gigabytes"
  type        = number
  default     = 30
  nullable    = false
}
variable "service_name" {
  description = "Descriptive name of a service that will use this VPC"
  type        = string
  default     = "website"
}

variable "on_demand_base_capacity" {
  description = "If specified, the ASG will request spot instances and this will be the minimal number of on-demand instances."
  type        = number
  default     = null
}

variable "ssh_cidr_block" {
  description = "CIDR range that is allowed to SSH into the backend instances.  Format is a.b.c.d/<prefix>."
  type        = string
  default     = null
}

variable "subnets" {
  description = "Subnet ids where load balancer should be present"
  type        = list(string)
}

variable "stickiness_enabled" {
  description = "If true, enable stickiness on the target group ensuring a clients is forwarded to the same target."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources creatded by the module."
  type        = map(string)
  default     = {}
}

variable "target_group_port" {
  description = "TCP port that a target listens to to serve requests from the load balancer."
  type        = number
  default     = 80
}

variable "target_group_type" {
  description = "Target group type: instance, ip, alb. Default is instance."
  type        = string
  default     = "instance"

  validation {
    condition     = contains(["instance", "ip", "alb"], var.target_group_type)
    error_message = "target_group_type must be one of: instance, ip, alb."
  }
}

variable "target_group_protocol" {
  description = <<-EOF
    Protocol for the target group.
    Use HTTP for standard backend communication (ALB terminates SSL).
    Use HTTPS for end-to-end encryption to backend instances.
  EOF
  type        = string
  default     = "HTTP"

  validation {
    condition     = contains(["HTTP", "HTTPS"], var.target_group_protocol)
    error_message = "target_group_protocol must be either 'HTTP' or 'HTTPS'."
  }
}

variable "load_balancing_algorithm_type" {
  description = <<-EOF
    Load balancing algorithm for the target group.

    **Available algorithms:**
    - `round_robin` (default): Distributes requests evenly across healthy targets.
      Best for: General-purpose workloads with similar request processing times.

    - `least_outstanding_requests`: Routes to the target with fewest in-flight requests.
      Best for: Workloads with varying request processing times, long-running requests,
      or when backend instances have different capacities.

    **Note:** When stickiness is enabled, the algorithm applies only to initial
    session assignment. Subsequent requests from the same client go to the same target.
  EOF
  type        = string
  default     = "round_robin"

  validation {
    condition     = contains(["round_robin", "least_outstanding_requests"], var.load_balancing_algorithm_type)
    error_message = "load_balancing_algorithm_type must be either 'round_robin' or 'least_outstanding_requests'."
  }
}

variable "target_group_deregistration_delay" {
  description = <<-EOF
    Time in seconds for ALB to wait before deregistering a target.
    During this time, the target continues to receive existing connections
    but no new connections. This allows in-flight requests to complete.

    Common use cases:
    - Reduce for faster deployments (e.g., 30s for stateless apps)
    - Increase for long-running requests (e.g., 600s for file uploads)

    Valid range: 0-3600 seconds. AWS default is 300 seconds.
  EOF
  type        = number
  default     = 300

  validation {
    condition     = var.target_group_deregistration_delay >= 0 && var.target_group_deregistration_delay <= 3600
    error_message = "Deregistration delay must be between 0 and 3600 seconds."
  }
}

variable "upstream_module" {
  description = "Module that called this module."
  type        = string
  default     = null
}

variable "userdata" {
  description = "userdata for cloud-init to provision EC2 instances"
  type        = string
}

variable "vanta_owner" {
  description = "The email address of the instance's owner, and it should be set to the email address of a user in Vanta. An owner will not be assigned if there is no user in Vanta with the email specified."
  type        = string
  default     = null
}

variable "vanta_production_environments" {
  description = "Environment names to consider production grade in Vanta."
  type        = list(string)
  default = [
    "production",
    "prod"
  ]
}

variable "vanta_description" {
  description = "This tag allows administrators to set a description, for instance, or add any other descriptive information."
  type        = string
  default     = null
}

variable "vanta_contains_user_data" {
  description = "his tag allows administrators to define whether or not a resource contains user data (true) or if they do not contain user data (false)."
  type        = bool
  default     = false
}

variable "vanta_contains_ephi" {
  description = "This tag allows administrators to define whether or not a resource contains electronically Protected Health Information (ePHI). It can be set to either (true) or if they do not have ephi data (false)."
  type        = bool
  default     = false
}

variable "vanta_user_data_stored" {
  description = "This tag allows administrators to describe the type of user data the instance contains."
  type        = string
  default     = null
}

variable "vanta_no_alert" {
  description = "Administrators can add this tag to mark a resource as out of scope for their audit. If this tag is added, the administrator will need to set a reason for why it's not relevant to their audit."
  type        = string
  default     = null
}

variable "wait_for_capacity_timeout" {
  description = "How much time to wait until all instances are healthy"
  type        = string
  default     = "20m"
}

variable "zone_id" {
  description = "Domain name zone ID where the website will be available"
  type        = string
}

variable "certificate_issuers" {
  description = "List of certificate authority domains allowed to issue certificates for this domain (e.g., [\"amazon.com\", \"letsencrypt.org\"]). The module will format these as CAA records."
  type        = list(string)
  default     = ["amazon.com"]
}

variable "allow_wildcard_certificates" {
  description = <<-EOF
    If true, CAA records will allow wildcard certificates from the configured certificate_issuers.
    If false, wildcard certificates are blocked.
  EOF
  type        = bool
  default     = false
}

variable "attach_tagret_group_to_asg" {
  description = <<-EOF
    ⚠️  DEPRECATED - Contains typo, use 'attach_target_group_to_asg' instead.
    This variable will be removed in v6.0.0. See deprecations.tf for details.
    Whether to register ASG instances in the target group. Disable if using ECS which registers targets itself.
  EOF
  type        = bool
  default     = null
}

variable "attach_target_group_to_asg" {
  description = "Whether to register ASG instances in the target group. Disable if using ECS which registers targets itself."
  type        = bool
  default     = true
}

variable "sns_topic_alarm_arn" {
  description = "ARN of SNS topic for Cloudwatch alarms on base EC2 instance."
  type        = string
  default     = null
}

# Vanta Compliance: CloudWatch Alarms
variable "alarm_emails" {
  description = <<-EOF
    List of email addresses to receive CloudWatch alarm notifications for ALB monitoring.

    ⚠️  **IMPORTANT - EMAIL CONFIRMATION REQUIRED:**
    After deployment, AWS SNS will send a confirmation email to each address.
    **You MUST click the confirmation link** in each email to activate notifications.

    Until confirmed:
    - Subscription status: PendingConfirmation
    - Alarms will fire but notifications will NOT be delivered
    - No alerts will reach your team during incidents

    **Action Required:** Check spam folders and confirm all subscription emails immediately after deployment.

    **Vanta Compliance Requirements:**
    When configured, creates CloudWatch alarms for:
    - Load balancer unhealthy host count monitoring
    - Load balancer latency monitoring
    - Load balancer server errors (5xx) monitoring
    - Server CPU utilization monitoring

    **Example:**
    ```
    alarm_emails = ["ops-team@example.com", "on-call@example.com"]
    ```

    ⚠️  **FUTURE REQUIREMENT:** In v6.0.0, at least one email address will be required.
    See UPGRADE-6.0.md for migration details.
  EOF
  type        = list(string)
  default     = []
}

variable "alarm_topic_arns" {
  description = <<-EOF
    List of existing SNS topic ARNs to send ALB alarms to.
    Use this for advanced integrations like PagerDuty, Slack, OpsGenie, etc.

    These topics will receive notifications in addition to any configured alarm_emails.

    **Example:**
    ```
    alarm_topic_arns = [
      "arn:aws:sns:us-east-1:123456789012:pagerduty-critical",
      "arn:aws:sns:us-east-1:123456789012:slack-alerts"
    ]
    ```
  EOF
  type        = list(string)
  default     = []
}

variable "alarm_unhealthy_host_threshold" {
  description = <<-EOF
    Number of unhealthy hosts that triggers an alarm.

    Uses GreaterThanThreshold comparison, so:
    - 0 = Alert when ANY host becomes unhealthy (count > 0)
    - 1 = Alert when 2+ hosts are unhealthy (count > 1) - default
    - 2 = Alert when 3+ hosts are unhealthy (count > 2)

    **Recommended:** Set to 0 for immediate alerting in production, or 1 to allow
    for graceful deployments where one host may briefly be unhealthy during updates.
  EOF
  type        = number
  default     = 1

  validation {
    condition     = var.alarm_unhealthy_host_threshold >= 0
    error_message = "Unhealthy host threshold must be >= 0"
  }
}

variable "alarm_target_response_time_threshold" {
  description = <<-EOF
    Target response time threshold in seconds that triggers a latency alarm.

    If not specified, defaults to 80% of alb_idle_timeout to alert before
    connections start timing out.

    Example: With default alb_idle_timeout=60s, this will default to 48s.

    You can override this for more aggressive monitoring:
    - API services: 0.5 - 1.0 seconds
    - Web applications: 1.0 - 2.0 seconds
    - Backend services: 2.0 - 5.0 seconds
  EOF
  type        = number
  default     = null

  validation {
    condition     = var.alarm_target_response_time_threshold == null ? true : (var.alarm_target_response_time_threshold > 0 && var.alarm_target_response_time_threshold <= 3600)
    error_message = <<-EOF
      Response time threshold must be between 0 and 3600 seconds (1 hour).
      Upper limit is generous to support edge cases like file uploads, batch processing,
      and streaming, while still catching obvious configuration errors.
    EOF
  }
}

variable "alarm_success_rate_threshold" {
  description = <<-EOF
    Minimum success rate (percentage) before triggering an alarm.

    Success rate = (non-5xx responses) / (total responses) * 100

    This is smarter than a raw error count because it scales with traffic volume.
    A 1% error rate means the same thing whether you have 100 or 100,000 requests.

    **Default:** 99.0 (alerts when error rate exceeds 1%)

    **Examples:**
    - 99.9 = Alert when more than 0.1% of requests fail (very strict SLO)
    - 99.0 = Alert when more than 1% of requests fail (recommended)
    - 95.0 = Alert when more than 5% of requests fail (lenient)

    **Note:** Alarms won't trigger during periods with zero traffic.
  EOF
  type        = number
  default     = 99.0

  validation {
    condition     = var.alarm_success_rate_threshold >= 0 && var.alarm_success_rate_threshold <= 100
    error_message = "Success rate threshold must be between 0 and 100 (percentage)"
  }
}

variable "alarm_success_rate_period" {
  description = <<-EOF
    Time period (in seconds) over which to calculate the success rate.

    Longer periods provide more statistical stability, especially important
    for low-traffic sites where individual errors can skew short-term rates.

    **Default:** 300 seconds (5 minutes)

    **Recommendations by traffic volume:**
    - Very low traffic (< 1 req/min):   3600s (1 hour) for statistical significance
    - Low traffic (1-10 req/min):       900s (15 min)
    - Medium traffic (10-100 req/min):  300s (5 min) - default
    - High traffic (> 100 req/min):     60s (1 min) for faster detection

    **Detection time:** With evaluation_periods=2:
    - 3600s (1 hour) = 2 hour detection time
    - 900s (15 min) = 30 minute detection time
    - 300s (5 min) = 10 minute detection time
    - 60s (1 min) = 2 minute detection time

    **Example for low-traffic site:**
    ```
    alarm_success_rate_period = 3600  # 1 hour window
    alarm_success_rate_threshold = 99.0
    ```
    With 10 requests/hour, allows 1 error before alarming.
  EOF
  type        = number
  default     = 300 # 5 minutes

  validation {
    condition     = contains([60, 300, 900, 3600], var.alarm_success_rate_period)
    error_message = "Period must be 60 (1 min), 300 (5 min), 900 (15 min), or 3600 (1 hour)"
  }
}

variable "alarm_cpu_utilization_threshold" {
  description = <<-EOF
    CPU utilization percentage that triggers an alarm.

    This alarm detects when autoscaling FAILS to keep up with demand, which may indicate:
    - ASG reached max_size (cannot scale further)
    - New instances failing to provision
    - New instances not becoming healthy
    - Infrastructure capacity/quota issues

    **Automatic calculation:**
    If not specified, defaults to autoscaling_target_cpu_load + 30%.
    This provides a buffer for autoscaling to respond before alarming.

    **Example automatic thresholds:**
    - autoscaling_target_cpu_load = 60%: alarm at 90%
    - autoscaling_target_cpu_load = 70%: alarm at 99% (capped)

    **How it works:**
    When CPU exceeds target (60% default), ASG launches new instances (~5-10 min).
    If CPU stays high for 10 minutes (period × evaluation_periods), autoscaling has failed - time to alert!

    **Override for custom thresholds:**
    ```
    alarm_cpu_utilization_threshold = 85  # Explicit threshold
    ```

    **Note:** This is a Vanta compliance requirement (Server CPU monitored).
  EOF
  type        = number
  default     = null

  validation {
    condition     = var.alarm_cpu_utilization_threshold == null ? true : (var.alarm_cpu_utilization_threshold > 0 && var.alarm_cpu_utilization_threshold < 100)
    error_message = <<-EOF
      CPU utilization threshold must be between 0 and 99 (percentage).
      Threshold of 100 would never trigger since the alarm uses GreaterThanThreshold comparison.
    EOF
  }
}

variable "alarm_evaluation_periods" {
  description = <<-EOF
    Number of periods over which to compare the metric to the threshold.

    With 1-minute periods, setting this to 2 means the alarm must breach
    for 2 consecutive minutes before triggering.
  EOF
  type        = number
  default     = 2

  validation {
    condition     = var.alarm_evaluation_periods >= 1
    error_message = "Evaluation periods must be at least 1"
  }
}
