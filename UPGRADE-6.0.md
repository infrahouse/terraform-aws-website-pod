# Upgrade Guide: v5.x to v6.0.0

This guide helps you migrate from v5.x to v6.0.0 of the `terraform-aws-website-pod` module.

## Overview

Version 6.0.0 removes deprecated variables that contained typos. These variables have shown deprecation warnings since v5.7.0, giving users time to migrate.

## Breaking Changes

### 1. Removed Variable: `alb_healthcheck_uhealthy_threshold`

**What Changed**: The misspelled variable `alb_healthcheck_uhealthy_threshold` has been removed.

**Migration**: Use the correctly-spelled `alb_healthcheck_unhealthy_threshold` instead.

**Before (v5.x)**:
```hcl
module "website_pod" {
  source  = "infrahouse/website-pod/aws"
  version = "~> 5.0"

  alb_healthcheck_uhealthy_threshold = 3  # Typo: "uhealthy"
}
```

**After (v6.x)**:
```hcl
module "website_pod" {
  source  = "infrahouse/website-pod/aws"
  version = "~> 6.0"

  alb_healthcheck_unhealthy_threshold = 3  # Correct spelling
}
```

### 2. Removed Variable: `attach_tagret_group_to_asg`

**What Changed**: The misspelled variable `attach_tagret_group_to_asg` has been removed.

**Migration**: Use the correctly-spelled `attach_target_group_to_asg` instead.

**Before (v5.x)**:
```hcl
module "website_pod" {
  source  = "infrahouse/website-pod/aws"
  version = "~> 5.0"

  attach_tagret_group_to_asg = true  # Typo: "tagret"
}
```

**After (v6.x)**:
```hcl
module "website_pod" {
  source  = "infrahouse/website-pod/aws"
  version = "~> 6.0"

  attach_target_group_to_asg = true  # Correct spelling
}
```

## Migration Steps

### Step 1: Identify Usage

Search your Terraform code for the deprecated variables:

```bash
# Search for the deprecated variables
grep -r "alb_healthcheck_uhealthy_threshold" .
grep -r "attach_tagret_group_to_asg" .
```

### Step 2: Update Variable Names

Replace any occurrences with the correctly-spelled versions:

| Old Variable (Deprecated)           | New Variable (Correct)               |
|-------------------------------------|--------------------------------------|
| `alb_healthcheck_uhealthy_threshold`| `alb_healthcheck_unhealthy_threshold`|
| `attach_tagret_group_to_asg`        | `attach_target_group_to_asg`         |

### Step 3: Test with v5.11.0 First

Before upgrading to v6.0.0, test your changes with v5.11.0, which supports both old and new variable names:

```hcl
module "website_pod" {
  source  = "infrahouse/website-pod/aws"
  version = "~> 5.11"  # Test with latest v5.x first

  # Use new correctly-spelled variables
  alb_healthcheck_unhealthy_threshold = 3
  attach_target_group_to_asg          = true
}
```

Run `terraform plan` and verify:
- ✅ No deprecation warnings appear
- ✅ No changes to infrastructure (plan should show no changes)

### Step 4: Upgrade to v6.0.0

Once testing is successful, upgrade to v6.0.0:

```hcl
module "website_pod" {
  source  = "infrahouse/website-pod/aws"
  version = "~> 6.0"  # Upgrade to v6.0.0

  # Continue using correctly-spelled variables
  alb_healthcheck_unhealthy_threshold = 3
  attach_target_group_to_asg          = true
}
```

Run:
```bash
terraform init -upgrade
terraform plan
terraform apply
```

## New Features in v6.0.0

In addition to removing deprecated variables, v6.0.0 includes new features from the v5.x series:

### Enhanced Validation
- Health check parameter validation (interval, timeout, thresholds)
- Cross-variable validation (timeout < interval)
- Enum validation for multiple variables

### New Configuration Options
- `target_group_deregistration_delay`: Control connection draining time (0-3600s)
- Improved variable descriptions with examples
- Better inline documentation

### New Outputs
- `alb_security_group_id`: Direct access to ALB security group ID
- `backend_security_group_id`: Direct access to backend security group ID

### Security Improvements
- S3 bucket encryption for ALB access logs (enabled by default)
- S3 bucket versioning for ALB access logs (enabled by default)

## Troubleshooting

### Error: "Unsupported argument"

If you see:
```
Error: Unsupported argument
  on main.tf line X:
   X:   alb_healthcheck_uhealthy_threshold = 3

An argument named "alb_healthcheck_uhealthy_threshold" is not expected here.
```

**Solution**: You're using the old misspelled variable name. Update to `alb_healthcheck_unhealthy_threshold`.

### Deprecation Warnings in v5.x

If you see warnings like:
```
Warning: Deprecated variable used
  on main.tf line X:
   X:   alb_healthcheck_uhealthy_threshold = 3

This variable is deprecated and will be removed in v6.0.0.
Use 'alb_healthcheck_unhealthy_threshold' instead.
```

**Solution**: Update to the new variable name before upgrading to v6.0.0.

## Rollback

If you need to rollback to v5.x:

```hcl
module "website_pod" {
  source  = "infrahouse/website-pod/aws"
  version = "~> 5.11"  # Rollback to v5.11.x

  # Both old and new variable names work in v5.11.x
}
```

Run:
```bash
terraform init -upgrade
terraform plan
terraform apply
```

## Need Help?

- 📚 [Module Documentation](https://registry.terraform.io/modules/infrahouse/website-pod/aws/latest)
- 🐛 [Report Issues](https://github.com/infrahouse/terraform-aws-website-pod/issues)
- 📝 [CHANGELOG](CHANGELOG.md)

## Summary Checklist

- [ ] Search codebase for deprecated variable names
- [ ] Replace `alb_healthcheck_uhealthy_threshold` with `alb_healthcheck_unhealthy_threshold`
- [ ] Replace `attach_tagret_group_to_asg` with `attach_target_group_to_asg`
- [ ] Test with v5.11.0 first (verify no deprecation warnings)
- [ ] Verify `terraform plan` shows no infrastructure changes
- [ ] Upgrade to v6.0.0
- [ ] Run `terraform init -upgrade`
- [ ] Run `terraform plan` and verify expected changes
- [ ] Apply changes with `terraform apply`