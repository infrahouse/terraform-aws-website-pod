# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## First Steps

**Your first tool call in this repository MUST be reading .claude/CODING_STANDARD.md.
Do not read any other files, search, or take any actions until you have read it.**
This contains InfraHouse's comprehensive coding standards for Terraform, Python, and general formatting rules.

## Module Overview

`terraform-aws-website-pod` (v5.17.0) creates a production-ready HTTP service deployment on AWS with:
- ALB (Application Load Balancer) with SSL termination on port 443
- ACM certificate auto-issuance and DNS validation
- ASG (Auto Scaling Group) with launch templates and CPU-based target tracking
- Route53 DNS records (simple and weighted routing policies)
- CAA records for certificate issuer control
- Security groups for ALB and backend instances
- CloudWatch alarms (unhealthy hosts, latency, success rate, CPU) with SNS notifications for Vanta compliance
- Optional S3 access logging, spot instances, and lifecycle hooks

Requires two AWS providers: default (for resources) and `aws.dns` (for Route53 records).

## Common Commands

```bash
make bootstrap          # Install Python deps + git hooks (run in virtualenv)
make test               # Run full test suite (CI mode)
make test-keep          # Run tests, keep infrastructure for debugging
make test-clean         # Run tests with cleanup (before PR)
make lint               # Check formatting (black --check tests, terraform fmt -check)
make format             # Auto-format (terraform fmt -recursive, black tests)
make validate           # terraform init -backend=false && terraform validate
make release-patch      # Bump patch version (requires git-cliff, bumpversion)
make release-minor      # Bump minor version
make release-major      # Bump major version
```

### Running a Single Test

```bash
# Run specific test file with specific AWS provider version
pytest -xvvs tests/test_create_lb.py -k "internet-facing and aws-6"

# Using Makefile variables
make test-clean TEST_PATH=tests/test_create_lb.py TEST_FILTER="internet-facing and aws-6"
```

## Architecture

### Resource Dependency Flow

```
zone_id (Route53) ──> ssl.tf (ACM cert + DNS validation)
                           │
subnets ──> main.tf (ALB + listeners + target group) ──> dns.tf (A records, CAA records)
                           │
backend_subnets ──> asg.tf (ASG + launch template) ──> autoscaling.tf (CPU scaling policy)
                           │
                    iam.tf (instance profile via registry.infrahouse.com module)
```

### Key Terraform Files

| File | Purpose |
|------|---------|
| `main.tf` | ALB, listeners (HTTP redirect + HTTPS), listener rules, target group |
| `asg.tf` | ASG, launch template, lifecycle hooks |
| `ssl.tf` | ACM certificate, DNS validation records |
| `dns.tf` | Route53 A records (simple/weighted), CAA records |
| `alarms.tf` | CloudWatch alarms + SNS topic for Vanta compliance |
| `autoscaling.tf` | CPU-based target tracking scaling policy |
| `security_group_alb.tf` | ALB security group (ingress on 80/443, ICMP) |
| `security_group_backend.tf` | Backend SG (SSH from VPC, traffic from ALB, healthcheck) |
| `s3.tf` | Optional S3 bucket for ALB access logs |
| `locals.tf` | Tags, computed thresholds, deprecated variable coalescing |
| `deprecations.tf` | Deprecated variable handling (typo migrations for v6.0.0) |

### ALB Listener Rule Priority

The module uses priority 99 for its forwarding rule, leaving 1-98 for higher-priority custom rules and 100+ for lower-priority rules.

### Dual Provider Pattern

```hcl
aws     # Default provider - creates ALB, ASG, security groups, ACM, alarms
aws.dns # DNS provider - creates Route53 records (may be a different account)
```

### Testing Architecture

Tests use **pytest** with **pytest-infrahouse** fixtures that create real AWS infrastructure:
- `conftest.py`: Sets `TERRAFORM_ROOT_DIR = "test_data"`, configures logging
- Each test writes `terraform.tfvars` and `terraform.tf` dynamically into `test_data/test_*` directories
- Tests are parametrized across **two AWS provider versions** (`~> 5.31`, `~> 6.0`) and subnet types (public/private)
- `terraform_apply` context manager handles init/apply/destroy
- Tests validate via boto3 calls (DNS records, ALB config, ASG health, CloudWatch alarms)
- Test timeout: 3600 seconds (1 hour)

### Version Management

Version is tracked in `.bumpversion.cfg` and updated in `locals.tf` (`module_version`), `README.md`, and `docs/*.md`.
Release creates a git tag that triggers `.github/workflows/release.yml`.

## Commit Convention

Conventional commits enforced by `hooks/commit-msg`:
```
feat|fix|docs|refactor|test|chore|security|perf|build|ci|revert|style[!]: description
```

## Pre-commit Hook

`hooks/pre-commit` runs `terraform fmt -check -recursive` and `terraform-docs` (auto-stages README.md changes).

## Key Conventions

- InfraHouse modules sourced from `registry.infrahouse.com` with **exact version pins**
- Vanta compliance tags on all resources (`VantaContainsUserData`, `VantaContainsEPHI`, etc.)
- Deprecated variables (typos) use `coalesce()` in `locals.tf` for backward compatibility
- Maximum line length: 120 characters for all files
- All files must end with a newline
- Validation blocks use **ternary operators** for nullable variables (not `||`)
- IAM policies use `aws_iam_policy_document` data sources (not inline JSON)
