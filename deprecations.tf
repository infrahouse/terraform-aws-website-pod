# deprecations.tf
#
# This file contains deprecation warnings for variables that will be removed
# in future major versions. See CHANGELOG.md for migration guidance.
#
# These check blocks will display warnings during terraform plan when deprecated
# variables are used, but will not block execution.

# Deprecation warning for alb_healthcheck_uhealthy_threshold (typo)
check "deprecated_variable_alb_healthcheck_uhealthy_threshold" {
  assert {
    condition     = var.alb_healthcheck_uhealthy_threshold == null
    error_message = <<-EOF
      ╔════════════════════════════════════════════════════════════════════════╗
      ║                      ⚠️  DEPRECATION NOTICE ⚠️                         ║
      ╚════════════════════════════════════════════════════════════════════════╝

      Variable: 'alb_healthcheck_uhealthy_threshold'
      Status:   DEPRECATED (typo in variable name)
      Reason:   Variable name should be 'unhealthy' not 'uhealthy'

      Action Required:
      Please update your Terraform configuration to use the corrected variable name:

        # OLD (deprecated):
        alb_healthcheck_uhealthy_threshold = 3

        # NEW (correct):
        alb_healthcheck_unhealthy_threshold = 3

      Timeline:
      - v5.11.0 (current): Both variables work, deprecation warning shown
      - v6.0.0 (Q2 2026): Old variable will be REMOVED

      Documentation:
      - See CHANGELOG.md for version history
      - See UPGRADE-6.0.md for detailed migration guide

      ════════════════════════════════════════════════════════════════════════
    EOF
  }
}

# Deprecation warning for attach_tagret_group_to_asg (typo)
check "deprecated_variable_attach_tagret_group_to_asg" {
  assert {
    condition     = var.attach_tagret_group_to_asg == null || var.attach_tagret_group_to_asg == true
    error_message = <<-EOF
      ╔════════════════════════════════════════════════════════════════════════╗
      ║                      ⚠️  DEPRECATION NOTICE ⚠️                         ║
      ╚════════════════════════════════════════════════════════════════════════╝

      Variable: 'attach_tagret_group_to_asg'
      Status:   DEPRECATED (typo in variable name)
      Reason:   Variable name should be 'target' not 'tagret'

      Action Required:
      Please update your Terraform configuration to use the corrected variable name:

        # OLD (deprecated):
        attach_tagret_group_to_asg = false

        # NEW (correct):
        attach_target_group_to_asg = false

      Timeline:
      - v5.11.0 (current): Both variables work, deprecation warning shown
      - v6.0.0 (Q2 2026): Old variable will be REMOVED

      Documentation:
      - See CHANGELOG.md for version history
      - See UPGRADE-6.0.md for detailed migration guide

      ════════════════════════════════════════════════════════════════════════
    EOF
  }
}

# Prevent using both old and new variables simultaneously
check "no_conflicting_deprecated_variables" {
  assert {
    condition = !(
      var.alb_healthcheck_uhealthy_threshold != null &&
      var.alb_healthcheck_unhealthy_threshold != null
    )
    error_message = <<-EOF
      ╔════════════════════════════════════════════════════════════════════════╗
      ║                         ⚠️  CONFLICT ERROR ⚠️                          ║
      ╚════════════════════════════════════════════════════════════════════════╝

      Cannot specify both 'alb_healthcheck_uhealthy_threshold' (deprecated)
      and 'alb_healthcheck_unhealthy_threshold' (current) variables.

      Please use only the current variable name:
        alb_healthcheck_unhealthy_threshold = <value>

      Remove the deprecated variable from your configuration.

      ════════════════════════════════════════════════════════════════════════
    EOF
  }

  assert {
    condition = !(
      var.attach_tagret_group_to_asg != null &&
      var.attach_target_group_to_asg != null
    )
    error_message = <<-EOF
      ╔════════════════════════════════════════════════════════════════════════╗
      ║                         ⚠️  CONFLICT ERROR ⚠️                          ║
      ╚════════════════════════════════════════════════════════════════════════╝

      Cannot specify both 'attach_tagret_group_to_asg' (deprecated)
      and 'attach_target_group_to_asg' (current) variables.

      Please use only the current variable name:
        attach_target_group_to_asg = <value>

      Remove the deprecated variable from your configuration.

      ════════════════════════════════════════════════════════════════════════
    EOF
  }
}

# Cross-variable validation: health check timeout must be less than interval
check "healthcheck_timeout_less_than_interval" {
  assert {
    condition     = var.alb_healthcheck_timeout < var.alb_healthcheck_interval
    error_message = <<-EOF
      ╔════════════════════════════════════════════════════════════════════════╗
      ║                    ⚠️  CONFIGURATION ERROR ⚠️                          ║
      ╚════════════════════════════════════════════════════════════════════════╝

      Health check timeout must be less than health check interval.

      Current configuration:
        - Health check timeout:  ${var.alb_healthcheck_timeout} seconds
        - Health check interval: ${var.alb_healthcheck_interval} seconds

      Problem:
        AWS requires that the timeout value is less than the interval value.
        The health check needs enough time between checks to process the timeout.

      Solution:
        Adjust your configuration so that timeout < interval. For example:

        # Good configuration:
        alb_healthcheck_timeout  = 4   # Time to wait for response
        alb_healthcheck_interval = 5   # Time between checks

      Common configurations:
        - Fast checks:    timeout = 2,  interval = 5  (default)
        - Normal checks:  timeout = 5,  interval = 10
        - Slow checks:    timeout = 10, interval = 30

      ════════════════════════════════════════════════════════════════════════
    EOF
  }
}

# Vanta Compliance: Recommend configuring CloudWatch alarms
check "vanta_alarms_recommended" {
  assert {
    condition     = length(var.alarm_emails) > 0 || length(var.alarm_topic_arns) > 0
    error_message = <<-EOF
      ╔════════════════════════════════════════════════════════════════════════╗
      ║                 ⚠️  VANTA COMPLIANCE RECOMMENDATION ⚠️                 ║
      ╚════════════════════════════════════════════════════════════════════════╝

      No CloudWatch alarm notifications are configured for this ALB.

      Vanta Compliance Requirements:
      Vanta requires monitoring for:
      - Load balancer unhealthy host count
      - Load balancer latency
      - Load balancer server errors (5xx)
      - Server CPU utilization

      To enable alarms, configure one of:

      1. Email notifications:
         alarm_emails = ["ops-team@example.com"]

      2. Existing SNS topics:
         alarm_topic_arns = ["arn:aws:sns:us-east-1:123456789012:alerts"]

      Timeline:
      - v5.12.0 (current): Alarms are OPTIONAL, warning shown
      - v6.0.0 (Q2 2026): At least one alarm_emails address will be REQUIRED

      This is a warning only - your deployment will proceed, but Vanta
      compliance checks may fail.

      Documentation:
      - See https://www.vanta.com/products/trust-center
      - See UPGRADE-6.0.md for migration details

      ════════════════════════════════════════════════════════════════════════
    EOF
  }
}

# Vanta Compliance: Validate CPU alarm threshold is sane
check "cpu_alarm_threshold_sane" {
  assert {
    condition     = local.alarm_cpu_threshold > var.autoscaling_target_cpu_load
    error_message = <<-EOF
      ╔════════════════════════════════════════════════════════════════════════╗
      ║                  ⚠️  CPU ALARM CONFIGURATION ERROR ⚠️                  ║
      ╚════════════════════════════════════════════════════════════════════════╝

      CPU alarm threshold (${local.alarm_cpu_threshold}%) must be greater than
      autoscaling target (${var.autoscaling_target_cpu_load}%).

      Current configuration:
      - autoscaling_target_cpu_load:     ${var.autoscaling_target_cpu_load}%
      - alarm_cpu_utilization_threshold: ${coalesce(var.alarm_cpu_utilization_threshold, "auto (${local.alarm_cpu_threshold}%)")}

      Problem:
      The alarm should trigger AFTER autoscaling attempts to scale up.
      If alarm threshold ≤ autoscaling target, the alarm will fire immediately
      without giving autoscaling a chance to respond.

      How autoscaling works:
      1. CPU exceeds target (${var.autoscaling_target_cpu_load}%) → ASG launches new instances (~5-10 min)
      2. If CPU stays high for 10 minutes → alarm fires (something is wrong!)

      Solution:
      # Let it auto-calculate (recommended)
      # alarm_cpu_utilization_threshold defaults to autoscaling_target_cpu_load + 30%

      # OR manually set it higher:
      alarm_cpu_utilization_threshold = ${var.autoscaling_target_cpu_load + 30}

      ════════════════════════════════════════════════════════════════════════
    EOF
  }
}