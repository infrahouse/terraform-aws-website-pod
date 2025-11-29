# Implementation Plan for Module Review Recommendations

**Target Release:** v5.11.0
**Strategy:** Graceful deprecation with backward compatibility
**Timeline:** Implement now, breaking changes deferred to v6.0.0

---

## Progress Tracking

- ✅ Phase 1 - Task 1.1: Create Deprecation System (COMPLETED)
- ✅ Phase 1 - Task 1.2: Add New Correctly-Named Variables (COMPLETED)
- ✅ Phase 1 - Task 1.3: Update Variable Usage Logic (COMPLETED)
- ✅ Phase 2 - Task 2.1: Add S3 Bucket Encryption (COMPLETED)
- ✅ Phase 2 - Task 2.2: Add S3 Bucket Versioning (COMPLETED)
- ✅ Phase 2 - Task 2.3: Complete ELB Account Map (COMPLETED)
- ✅ Phase 3 - Task 3.1: Add Health Check Validations (COMPLETED)
- ✅ Phase 3 - Task 3.2: Add Cross-Variable Validation (COMPLETED)
- ✅ Phase 3 - Task 3.3: Add Additional Variable Validations (COMPLETED)
- ⏭️ Phase 4 - Task 4.1: Make ALB Listener Rule Priority Configurable (SKIPPED - Documented instead)
- ✅ Phase 4 - Task 4.2: Add Target Group Deregistration Delay (COMPLETED)
- ✅ Phase 4 - Task 4.3: Add Simple Security Group Outputs (COMPLETED)
- ✅ Phase 5 - Task 5.1: Improve Variable Descriptions (COMPLETED)
- ✅ Phase 5 - Task 5.2: Add Inline Comments (COMPLETED)
- ⏭️ Phase 5 - Task 5.3: Update CHANGELOG.md (AUTOMATED via git-cliff)
- ⬜ Phase 5 - Task 5.4: Create UPGRADE-6.0.md
- ⬜ Phase 5 - Task 5.5: Update README.md
- ⬜ Phase 6 - Task 6.1: Update Module Version
- ⬜ Phase 6 - Task 6.2: Format and Validate
- ⬜ Phase 6 - Task 6.3: Run Tests

---

## Overview

This plan implements the recommendations from the Terraform module review while maintaining backward compatibility.
We'll use the "graceful deprecation" strategy where:

1. **v5.11.0 (this release)** - Add new features, deprecate old variables, maintain compatibility
2. **v6.0.0 (future)** - Remove deprecated variables and make breaking changes

---

## Phase 1: Critical Fixes & Deprecations

### Task 1.1: Create Deprecation System ✅ COMPLETED
**File:** `deprecations.tf` (new file)

**Action:** Create check blocks to warn users about deprecated variables

**Details:**
- Add check block for `alb_healthcheck_uhealthy_threshold` → `alb_healthcheck_unhealthy_threshold`
- Add check block for `attach_tagret_group_to_asg` → `attach_target_group_to_asg`
- Add check to prevent using both old and new variables simultaneously
- Include helpful error messages with migration examples

**Why:** Provides visible warnings during `terraform plan` without breaking existing deployments

**Acceptance Criteria:**
- ✅ Users see warnings when using deprecated variables
- ✅ Warnings include migration instructions
- ✅ Doesn't block execution

**Status:** COMPLETED - deprecations.tf created with comprehensive check blocks

---

### Task 1.2: Add New Correctly-Named Variables ✅ COMPLETED
**File:** `variables.tf`

**Action:** Add new variables with correct names

**Variables to add:**
```hcl
# New correct variable
variable "alb_healthcheck_unhealthy_threshold" {
  description = "Number of consecutive health check failures required before considering the target unhealthy"
  type        = number
  default     = null
}

# New correct variable
variable "attach_target_group_to_asg" {
  description = "Whether to register ASG instances in the target group. Disable if using ECS which registers targets itself."
  type        = bool
  default     = null
}
```

**Update existing variables:**
- Mark `alb_healthcheck_uhealthy_threshold` as deprecated in description
- Mark `attach_tagret_group_to_asg` as deprecated in description
- Keep default = null for backward compatibility

**Why:** Allows users to migrate at their own pace while keeping old code working

**Acceptance Criteria:**
- ✅ Both old and new variables coexist
- ✅ Deprecated variables have clear warnings in descriptions
- ✅ No breaking changes to existing users

**Status:** COMPLETED - New variables added, deprecated variables updated with warnings

---

### Task 1.3: Update Variable Usage Logic ✅ COMPLETED
**File:** `locals.tf` or relevant resource files

**Action:** Use `coalesce()` to support both old and new variables

**Implementation:**
```hcl
locals {
  # Priority: new variable > old variable > default  # Backward compatibility for deprecated variables with typos
  # Priority: new variable > old variable > default (the default is already set on the new variable)
  unhealthy_threshold = coalesce(
    var.alb_healthcheck_unhealthy_threshold,
    var.alb_healthcheck_uhealthy_threshold,
  )

  attach_tg_to_asg = coalesce(
    var.attach_target_group_to_asg,
    var.attach_tagret_group_to_asg,
  )
}
```

**Update usages:**
- `main.tf:124` - Replace `var.alb_healthcheck_uhealthy_threshold` with `local.unhealthy_threshold`
- `asg.tf:13` - Replace `var.attach_tagret_group_to_asg` with `local.attach_tg_to_asg`

**Why:** Maintains backward compatibility while supporting new variable names

**Acceptance Criteria:**
- ✅ New variable takes precedence if set
- ✅ Falls back to old variable if new one not set
- ✅ Uses default if neither is set
- ✅ All existing deployments continue working

**Status:** COMPLETED - Added coalesce logic in locals.tf, updated main.tf:124 and asg.tf:13

---

## Phase 2: Security Improvements

### Task 2.1: Add S3 Bucket Encryption ✅ COMPLETED
**File:** `s3.tf`

**Action:** Add server-side encryption to access log bucket

**Implementation:**
```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "access_log" {
  count  = var.alb_access_log_enabled ? 1 : 0
  bucket = aws_s3_bucket.access_log[count.index].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

**Why:**
- Security best practice
- May contain sensitive information (IPs, request patterns)
- Required for many compliance frameworks

**Acceptance Criteria:**
- ✅ Encryption enabled for new buckets
- ✅ Existing buckets get encryption added (non-breaking)
- ✅ Uses AES256 (S3-managed keys)

---

### Task 2.2: Add S3 Bucket Versioning ✅ COMPLETED
**File:** `s3.tf`

**Action:** Enable versioning for audit trail

**Implementation:**
```hcl
resource "aws_s3_bucket_versioning" "access_log" {
  count  = var.alb_access_log_enabled ? 1 : 0
  bucket = aws_s3_bucket.access_log[count.index].id

  versioning_configuration {
    status = "Enabled"
  }
}
```

**Why:**
- Audit trail for access logs
- Protection against accidental deletion
- Best practice for compliance

**Acceptance Criteria:**
- ✅ Versioning enabled for new buckets
- ✅ Existing buckets get versioning enabled (non-breaking)

---

### Task 2.3: Complete ELB Account Map ✅ COMPLETED
**File:** `locals.tf`

**Action:** Add all AWS regions to elb_account_map

**Current state:** Only 4 regions (us-east-1, us-east-2, us-west-1, us-west-2)

**Add regions:**
```hcl
elb_account_map = {
  "us-east-1"      = "127311923021"
  "us-east-2"      = "033677994240"
  "us-west-1"      = "027434742980"
  "us-west-2"      = "797873946194"
  "ca-central-1"   = "985666609251"
  "eu-central-1"   = "054676820928"
  "eu-west-1"      = "156460612806"
  "eu-west-2"      = "652711504416"
  "eu-west-3"      = "009996457667"
  "eu-north-1"     = "897822967062"
  "ap-east-1"      = "754344448648"
  "ap-northeast-1" = "582318560864"
  "ap-northeast-2" = "600734575887"
  "ap-northeast-3" = "383597477331"
  "ap-southeast-1" = "114774131450"
  "ap-southeast-2" = "783225319266"
  "ap-southeast-3" = "589379963580"
  "ap-southeast-4" = "297686090294"
  "ap-south-1"     = "718504428378"
  "ap-south-2"     = "635631232127"
  "sa-east-1"      = "507241528517"
  "me-south-1"     = "076674570225"
  "me-central-1"   = "741774495389"
  "af-south-1"     = "098369216593"
  "eu-south-1"     = "635631232127"
  "eu-south-2"     = "732548202433"
  "eu-central-2"   = "503297430113"
  "il-central-1"   = "581348220920"
}
```

**Reference:** https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html

**Why:** Module will fail in non-US regions when access logging is enabled

**Acceptance Criteria:**
- ✅ All AWS regions supported
- ✅ Access logging works in any region
- ✅ Include comment with reference link

---

## Phase 3: Variable Validations

### Task 3.1: Add Health Check Validations ✅ COMPLETED
**File:** `variables.tf`

**Action:** Add validation rules to catch configuration errors early

**Variables to validate:**

1. **alb_healthcheck_interval**
```hcl
validation {
  condition     = var.alb_healthcheck_interval >= 5 && var.alb_healthcheck_interval <= 300
  error_message = "Health check interval must be between 5 and 300 seconds."
}
```

2. **alb_healthcheck_timeout**
```hcl
validation {
  condition     = var.alb_healthcheck_timeout >= 2 && var.alb_healthcheck_timeout <= 120
  error_message = "Health check timeout must be between 2 and 120 seconds."
}
```

3. **alb_healthcheck_healthy_threshold**
```hcl
validation {
  condition     = var.alb_healthcheck_healthy_threshold >= 2 && var.alb_healthcheck_healthy_threshold <= 10
  error_message = "Healthy threshold must be between 2 and 10."
}
```

4. **alb_healthcheck_unhealthy_threshold** (new variable)
```hcl
validation {
  condition     = var.alb_healthcheck_unhealthy_threshold == null || (var.alb_healthcheck_unhealthy_threshold >= 2 && var.alb_healthcheck_unhealthy_threshold <= 10)
  error_message = "Unhealthy threshold must be between 2 and 10."
}
```

**Why:** Prevents invalid AWS API calls and catches errors during plan phase

**Acceptance Criteria:**
- ✅ Validations match AWS API constraints
- ✅ Error messages are clear and helpful
- ✅ Null values handled for optional variables

---

### Task 3.2: Add Cross-Variable Validation ✅ COMPLETED
**File:** `deprecations.tf` or new `validations.tf`

**Action:** Validate relationships between variables

**Implementation:**
```hcl
check "healthcheck_timeout_less_than_interval" {
  assert {
    condition     = var.alb_healthcheck_timeout < var.alb_healthcheck_interval
    error_message = <<-EOF
      Health check timeout (${var.alb_healthcheck_timeout}s) must be less than
      health check interval (${var.alb_healthcheck_interval}s).

      Current configuration:
        - Timeout:  ${var.alb_healthcheck_timeout} seconds
        - Interval: ${var.alb_healthcheck_interval} seconds

      Please adjust these values so timeout < interval.
    EOF
  }
}
```

**Why:** AWS requires timeout < interval, catch this early

**Acceptance Criteria:**
- ✅ Prevents invalid configurations
- ✅ Clear error message with current values
- ✅ Shows during terraform plan

---

### Task 3.3: Add Additional Variable Validations ✅ COMPLETED
**File:** `variables.tf`

**Variables to validate:**

1. **max_instance_lifetime_days**
```hcl
validation {
  condition     = var.max_instance_lifetime_days == 0 || (var.max_instance_lifetime_days >= 7 && var.max_instance_lifetime_days <= 365)
  error_message = "max_instance_lifetime_days must be 0 (unlimited) or between 7 and 365 days."
}
```

2. **target_group_type**
```hcl
validation {
  condition     = contains(["instance", "ip", "alb"], var.target_group_type)
  error_message = "target_group_type must be one of: instance, ip, alb."
}
```

3. **health_check_type**
```hcl
validation {
  condition     = contains(["EC2", "ELB"], var.health_check_type)
  error_message = "health_check_type must be either 'EC2' or 'ELB'."
}
```

4. **alb_healthcheck_protocol**
```hcl
validation {
  condition     = contains(["HTTP", "HTTPS"], var.alb_healthcheck_protocol)
  error_message = "alb_healthcheck_protocol must be either 'HTTP' or 'HTTPS'."
}
```

5. **asg_scale_in_protected_instances**
```hcl
validation {
  condition     = contains(["Refresh", "Ignore", "Wait"], var.asg_scale_in_protected_instances)
  error_message = "asg_scale_in_protected_instances must be one of: Refresh, Ignore, Wait."
}
```

**Why:** Fail fast with clear error messages instead of AWS API errors

**Acceptance Criteria:**
- ✅ All enum-like variables validated
- ✅ Range validations for numeric variables
- ✅ Clear error messages

---

## Phase 4: Feature Enhancements

### Task 4.1: Make ALB Listener Rule Priority Configurable ⏭️ SKIPPED
**File:** `main.tf:87-90`

**Decision:** Document hardcoded priority instead of making it configurable

**Rationale:**
- Users have never requested this feature
- 99% of use cases involve a single target group
- Priority 99 leaves plenty of room for custom rules (1-98 higher, 100+ lower)
- YAGNI principle - don't add complexity without demonstrated need
- Simpler module with fewer variables to maintain

**Action Taken:** Added inline comment documenting the fixed priority

**Implementation:**
```hcl
variable "alb_listener_rule_priority" {
  description = "Priority for the ALB listener rule (1-50000). Lower numbers have higher priority."
  type        = number
  default     = 99

  validation {
    condition     = var.alb_listener_rule_priority >= 1 && var.alb_listener_rule_priority <= 50000
    error_message = "Listener rule priority must be between 1 and 50000."
  }
}
```

**File:** `main.tf:87`

**Update:**
```hcl
resource "aws_alb_listener_rule" "website" {
  listener_arn = aws_lb_listener.ssl.arn
  priority     = var.alb_listener_rule_priority  # Changed from hardcoded 99
  # ... rest unchanged
}
```

**Why:** Allows users to control rule priority when adding multiple listener rules

**Acceptance Criteria:**
- ✅ Default value is 99 (maintains backward compatibility)
- ✅ Validation ensures valid range
- ✅ Documentation explains priority behavior

---

### Task 4.2: Add Target Group Deregistration Delay ✅ COMPLETED
**File:** `variables.tf`, `main.tf`

**Action:** Add variable for deregistration delay

**Implementation:**
```hcl
variable "target_group_deregistration_delay" {
  description = <<-EOF
    Time in seconds for ALB to wait before deregistering a target.
    During this time, the target continues to receive existing connections
    but no new connections. Valid range: 0-3600 seconds.
  EOF
  type        = number
  default     = 300

  validation {
    condition     = var.target_group_deregistration_delay >= 0 && var.target_group_deregistration_delay <= 3600
    error_message = "Deregistration delay must be between 0 and 3600 seconds."
  }
}
```

**File:** `main.tf:108`

**Update:**
```hcl
resource "aws_alb_target_group" "website" {
  port                 = var.target_group_port
  protocol             = "HTTP"
  target_type          = var.target_group_type
  vpc_id               = data.aws_subnet.selected.vpc_id
  deregistration_delay = var.target_group_deregistration_delay  # Add this line

  stickiness {
    type    = "lb_cookie"
    enabled = var.stickiness_enabled
  }
  # ... rest unchanged
}
```

**Why:**
- Allows faster deployments (reduce delay)
- Or more graceful shutdowns (increase delay)
- Common use case for production deployments

**Acceptance Criteria:**
- ✅ Default 300s maintains current behavior
- ✅ Validation ensures valid range
- ✅ Documentation explains use case

---

### Task 4.3: Add Simple Security Group Outputs ✅ COMPLETED
**File:** `outputs.tf`

**Action:** Add dedicated outputs for security group IDs

**Implementation:**
```hcl
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "backend_security_group_id" {
  description = "ID of the backend instances security group"
  value       = aws_security_group.backend.id
}
```

**Why:**
- Easier to reference in other modules
- Don't need to parse complex map structure
- Common use case

**Acceptance Criteria:**
- ✅ Simple string outputs
- ✅ Clear descriptions
- ✅ Doesn't break existing `backend_security_group` output

---

## Phase 5: Documentation Improvements

### Task 5.1: Improve Variable Descriptions ✅ COMPLETED
**File:** `variables.tf`

**Action:** Use HEREDOC for long descriptions

**Examples to improve:**

1. **instance_profile_permissions**
```hcl
variable "instance_profile_permissions" {
  description = <<-EOF
    A JSON policy document to attach to the instance profile.
    This should be the output of an aws_iam_policy_document data source.

    Example:
      instance_profile_permissions = data.aws_iam_policy_document.my_policy.json

    If not specified, defaults to a minimal policy allowing sts:GetCallerIdentity.
  EOF
  type    = string
  default = null
}
```

2. **asg_lifecycle_hook_initial vs asg_lifecycle_hook_launching**
```hcl
variable "asg_lifecycle_hook_initial" {
  description = <<-EOF
    Name for an initial LAUNCHING lifecycle hook configured via the initial_lifecycle_hook
    block in the ASG. This hook is evaluated during ASG creation.
    Only one initial hook is allowed per ASG.

    Use this for simple lifecycle hooks that don't require additional configuration.
  EOF
  type    = string
  default = null
}

variable "asg_lifecycle_hook_launching" {
  description = <<-EOF
    Name for a LAUNCHING lifecycle hook configured via a separate
    aws_autoscaling_lifecycle_hook resource. This allows for more complex configurations
    and can be created after the ASG exists.

    Use this if you need to attach SNS notifications or additional settings to the lifecycle hook.
  EOF
  type    = string
  default = null
}
```

**Why:** Makes variables easier to understand and use correctly

**Acceptance Criteria:**
- ✅ Key variables have detailed descriptions
- ✅ Examples included where helpful
- ✅ HEREDOC used for multi-line descriptions

---

### Task 5.2: Add Inline Comments ✅ COMPLETED
**Files:** Various `.tf` files

**Action:** Add explanatory comments for complex logic

**Locations:**

1. **asg.tf:98** - Root volume calculation
```hcl
block_device_mappings {
  device_name = data.aws_ami.selected.root_device_name
  ebs {
    # Root volume size = user-specified size + swap space
    # Swap space = 2 * RAM size (instance memory converted from MiB to GiB)
    # This ensures adequate swap space for the instance type
    volume_size           = var.root_volume_size + 2 * data.aws_ec2_instance_type.selected.memory_size / 1024
    delete_on_termination = true
  }
}
```

2. **main.tf:6** - Internal/external ALB logic
```hcl
# ALB is internal if subnets don't auto-assign public IPs
# Otherwise, it's internet-facing (publicly accessible)
internal = !data.aws_subnet.selected.map_public_ip_on_launch
```

3. **security_group_backend.tf:76** - Conditional healthcheck rule
```hcl
# Add dedicated healthcheck security group rule only if the healthcheck port
# differs from the target group port. If they're the same, the main traffic
# rule (backend_user_traffic) already allows the healthcheck traffic.
count = var.alb_healthcheck_port == var.target_group_port || var.alb_healthcheck_port == "traffic-port" ? 0 : 1
```

4. **locals.tf:3** - Module version tag
```hcl
locals {
  module         = "infrahouse/website-pod/aws"
  module_version = "5.11.0"  # Applied to ALB as the primary resource per InfraHouse standards
```

**Why:** Makes code easier to understand and maintain

**Acceptance Criteria:**
- ✅ Complex logic has explanatory comments
- ✅ Comments explain "why" not just "what"
- ✅ Mathematical calculations explained

---

### Task 5.3: Update CHANGELOG.md ⏭️ AUTOMATED via git-cliff
**File:** `CHANGELOG.md`

**Decision:** Use git-cliff to auto-generate CHANGELOG from conventional commit messages

**Rationale:**
- git-cliff is already configured in `make release-*` targets
- Auto-generates from commit messages (conventional commits format)
- Avoids duplicate maintenance and merge conflicts
- Ensures consistency with commit history

**Implementation:**
1. ✅ Commit message validation hook installed (`hooks/commit-msg`)
2. ✅ All commits follow conventional commit format
3. ⬜ Run `make release-minor` when ready (git-cliff generates CHANGELOG automatically)
4. ⬜ Review and adjust generated CHANGELOG if needed (add migration notes, etc.)

**Conventional Commit Types Used:**
- `feat:` - New features (deregistration delay, security group outputs, etc.)
- `security:` - Security improvements (S3 encryption, versioning, region support)
- `docs:` - Documentation improvements (HEREDOC descriptions, inline comments)
- `fix:` - Bug fixes (typo corrections in variable names)

**Why:** Automated changelog from existing tooling, no duplicate maintenance

**Original Template (for reference):**
```markdown
## [5.11.0] - 2025-11-29

### Added
- New variable `alb_healthcheck_unhealthy_threshold` (correct spelling to replace typo)
- New variable `attach_target_group_to_asg` (correct spelling to replace typo)
- New variable `alb_listener_rule_priority` for configurable listener rule priority (default: 99)
- New variable `target_group_deregistration_delay` for configurable deregistration delay (default: 300s)
- New outputs `alb_security_group_id` and `backend_security_group_id` for easier reference
- S3 bucket server-side encryption for ALB access logs (AES256)
- S3 bucket versioning for ALB access logs
- Support for all AWS regions in ELB account map (previously only 4 US regions)
- Variable validations for health check parameters, instance lifetime, target group type, etc.
- Deprecation warnings using Terraform check blocks for typo'd variables
- Comprehensive inline documentation and comments

### Changed
- Improved variable descriptions using HEREDOC format for clarity
- Enhanced error messages in validations with actionable guidance

### Deprecated
- `alb_healthcheck_uhealthy_threshold` - Use `alb_healthcheck_unhealthy_threshold` instead (will be removed in v6.0.0)
- `attach_tagret_group_to_asg` - Use `attach_target_group_to_asg` instead (will be removed in v6.0.0)

### Security
- Added server-side encryption to S3 access log buckets (AES256)
- Added versioning to S3 access log buckets for audit trail

### Migration Notes
If you're using deprecated variables, you'll see warnings during `terraform plan`.
Both old and new variable names work in v5.11.0, but please migrate to the new names.
See UPGRADE-6.0.md for detailed migration instructions.

## [5.10.0] - Previous release
...
```

**Why:** Clear communication of changes and deprecations

**Acceptance Criteria:**
- ✅ All changes documented
- ✅ Deprecations clearly marked
- ✅ Security improvements highlighted
- ✅ Migration notes included

---

### Task 5.4: Create UPGRADE-6.0.md
**File:** `UPGRADE-6.0.md` (new file)

**Action:** Create migration guide for future v6.0.0

**Template:**
```markdown
# Upgrading to v6.0.0

**Status:** DRAFT - v6.0.0 is not yet released
**Planned Release:** Q2 2026
**Current Version:** v5.11.0

This guide helps you migrate from v5.x to v6.0.0 when it's released.

---

## Breaking Changes

### 1. Variable Renames (Typo Corrections)

Two variables with typos will be removed. You must use the corrected names.

#### alb_healthcheck_uhealthy_threshold → alb_healthcheck_unhealthy_threshold

**Before (v5.x):**
```hcl
module "website" {
  source  = "infrahouse/website-pod/aws"
  version = "~> 5.11"

  alb_healthcheck_uhealthy_threshold = 3
}
```

**After (v6.0.0):**
```hcl
module "website" {
  source  = "infrahouse/website-pod/aws"
  version = "~> 6.0"

  alb_healthcheck_unhealthy_threshold = 3  # Fixed typo
}
```

#### attach_tagret_group_to_asg → attach_target_group_to_asg

**Before (v5.x):**
```hcl
module "website" {
  source  = "infrahouse/website-pod/aws"
  version = "~> 5.11"

  attach_tagret_group_to_asg = false
}
```

**After (v6.0.0):**
```hcl
module "website" {
  source  = "infrahouse/website-pod/aws"
  version = "~> 6.0"

  attach_target_group_to_asg = false  # Fixed typo
}
```

### 2. Type Changes

#### alb_healthcheck_port

**Change:** Type changed from `any` to `string`

**Before (v5.x):**
```hcl
alb_healthcheck_port = 8080  # Unquoted number
```

**After (v6.0.0):**
```hcl
alb_healthcheck_port = "8080"  # String (or "traffic-port")
```

---

## Migration Checklist

- [ ] Search your codebase for `alb_healthcheck_uhealthy_threshold` and replace with `alb_healthcheck_unhealthy_threshold`
- [ ] Search your codebase for `attach_tagret_group_to_asg` and replace with `attach_target_group_to_asg`
- [ ] Ensure `alb_healthcheck_port` is quoted if you're setting it
- [ ] Run `terraform plan` to verify no issues
- [ ] Test in non-production environment first

---

## Testing Your Migration

1. Update to v5.11.0 first (maintains compatibility)
2. Run `terraform plan` - you should see deprecation warnings
3. Update variable names as shown above
4. Run `terraform plan` again - warnings should be gone
5. When v6.0.0 is released, update version constraint
6. Test thoroughly in non-production

---

## Getting Help

- Review CHANGELOG.md for detailed release notes
- Check GitHub issues for known migration issues
- Open an issue if you encounter problems
```

**Why:** Prepares users for future breaking changes

**Acceptance Criteria:**
- ✅ Clear migration steps
- ✅ Before/after examples
- ✅ Checklist for users
- ✅ Testing recommendations

---

### Task 5.5: Update README.md
**File:** `README.md`

**Action:** Add deprecation notice section

**Add near the top (after main description):**
```markdown
## ⚠️  Deprecation Notices

**Version 5.11.0+** deprecates the following variables due to typos. Both old and new names work in v5.x, but the old names will be **removed in v6.0.0**:

| Deprecated Variable | Use Instead | Removal Version |
|---------------------|-------------|-----------------|
| `alb_healthcheck_uhealthy_threshold` | `alb_healthcheck_unhealthy_threshold` | v6.0.0 (Q2 2026) |
| `attach_tagret_group_to_asg` | `attach_target_group_to_asg` | v6.0.0 (Q2 2026) |

See [UPGRADE-6.0.md](UPGRADE-6.0.md) for migration instructions.
```

**Why:** High visibility for users reading documentation

**Acceptance Criteria:**
- ✅ Visible in README
- ✅ Table format for easy scanning
- ✅ Links to migration guide

---

## Phase 6: Quality Assurance

### Task 6.1: Update Module Version
**File:** `locals.tf:3`

**Action:** Update version to 5.11.0

**Change:**
```hcl
module_version = "5.11.0"  # Previously 5.10.0
```

**Why:** Version tracking

---

### Task 6.2: Format and Validate
**Commands to run:**

```bash
# Format all Terraform files
terraform fmt -recursive

# Validate configuration
terraform init
terraform validate

# Check with tflint (if available)
tflint

# Check with terraform-docs (updates README)
terraform-docs markdown table --output-file README.md .
```

**Why:** Ensure code quality and up-to-date documentation

**Acceptance Criteria:**
- ✅ All files formatted
- ✅ Validation passes
- ✅ No linting errors
- ✅ README auto-generated sections updated

---

### Task 6.3: Run Tests
**Commands:**

```bash
# Run existing test suite
cd tests
pytest -v

# Test with both AWS provider versions
pytest -v -k "aws-5"
pytest -v -k "aws-6"
```

**Why:** Ensure no regressions

**Acceptance Criteria:**
- ✅ All existing tests pass
- ✅ Tests pass with both AWS provider v5 and v6
- ✅ No new warnings or errors

---

## Implementation Order

**Recommended sequence:**

1. **Phase 1** (Critical) - Deprecations system
   - Creates foundation for all other changes
   - Non-breaking, safe to implement first

2. **Phase 2** (Security) - S3 encryption and region support
   - Important security fixes
   - Non-breaking additions

3. **Phase 3** (Validations) - Variable validations
   - Improves user experience
   - May surface existing configuration issues (good!)

4. **Phase 4** (Features) - New configuration options
   - Enhances module capabilities
   - All backward compatible

5. **Phase 5** (Documentation) - Update docs
   - Final step after all code changes
   - Ensures documentation matches implementation

6. **Phase 6** (QA) - Testing and validation
   - Verification step
   - Run continuously during implementation

---

## Deferred to v6.0.0 (Future)

These items are NOT included in v5.11.0:

- ❌ Removing deprecated variables (breaking)
- ❌ Changing `alb_healthcheck_port` type to string (breaking)
- ❌ Enforcing strict validations that might break existing configs (breaking)

---

## Success Criteria

v5.11.0 is ready when:

- ✅ All Phase 1-5 tasks completed
- ✅ All tests passing
- ✅ Terraform fmt/validate clean
- ✅ Documentation updated (CHANGELOG, README, UPGRADE-6.0)
- ✅ Users with deprecated variables see clear warnings
- ✅ Users without deprecated variables see no warnings
- ✅ All changes are backward compatible
- ✅ No breaking changes introduced

---

## Estimated Timeline

- **Phase 1:** 1-2 hours
- **Phase 2:** 1 hour
- **Phase 3:** 2-3 hours
- **Phase 4:** 1-2 hours
- **Phase 5:** 2-3 hours
- **Phase 6:** 1 hour

**Total:** 8-12 hours of development time

---

## Notes

- Keep commits atomic (one task per commit)
- Test after each phase
- Update TODO list as tasks complete
- Ask for clarification if any requirements unclear
