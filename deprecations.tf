# Cross-variable validation: health check timeout must be less than interval
check "healthcheck_timeout_less_than_interval" {
  assert {
    condition     = var.alb_healthcheck_timeout < var.alb_healthcheck_interval
    error_message = <<-EOF
      Health check timeout must be less than health check interval.

      Current configuration:
        - Health check timeout:  ${var.alb_healthcheck_timeout} seconds
        - Health check interval: ${var.alb_healthcheck_interval} seconds

      AWS requires that the timeout value is less than the interval value.
      Adjust your configuration so that timeout < interval. For example:

        alb_healthcheck_timeout  = 4   # Time to wait for response
        alb_healthcheck_interval = 5   # Time between checks
    EOF
  }
}

# Validate weighted routing configuration
check "weighted_routing_requires_set_identifier" {
  assert {
    condition     = var.dns_routing_policy == "simple" || var.dns_set_identifier != null
    error_message = <<-EOF
      When using dns_routing_policy = "weighted", you must also set dns_set_identifier.

      Current configuration:
        - dns_routing_policy: ${var.dns_routing_policy}
        - dns_set_identifier: ${var.dns_set_identifier == null ? "null (not set)" : var.dns_set_identifier}

      Route53 weighted routing records require a unique set_identifier to distinguish
      between multiple records with the same name.

      Solution:
        dns_routing_policy = "weighted"
        dns_set_identifier = "my-service-v1"
    EOF
  }
}

# Validate CPU alarm threshold is above autoscaling target.
# Skipped when autoscaling_target_cpu_load is null (host-CPU scaling policy disabled):
# there is no target to compare against, and comparing a number to null errors.
check "cpu_alarm_threshold_sane" {
  assert {
    condition = (
      var.autoscaling_target_cpu_load == null
      ? true
      : local.alarm_cpu_threshold > var.autoscaling_target_cpu_load
    )
    error_message = <<-EOF
      CPU alarm threshold (${local.alarm_cpu_threshold}%) must be greater than
      autoscaling target (${var.autoscaling_target_cpu_load}%).

      The alarm should trigger AFTER autoscaling attempts to scale up.
      If alarm threshold <= autoscaling target, the alarm will fire immediately
      without giving autoscaling a chance to respond.

      Solution:
        alarm_cpu_utilization_threshold = ${var.autoscaling_target_cpu_load + 30}
    EOF
  }
}
