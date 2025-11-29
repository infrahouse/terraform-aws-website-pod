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