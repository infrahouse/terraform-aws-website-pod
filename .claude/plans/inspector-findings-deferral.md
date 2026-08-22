# Task: opt-in `InspectorEc2Exclusion` tag at launch

**Status:** implemented in the working tree on 2026-08-22 (everything except the release commit).
Reviewed against the repo and against the two modules that already shipped this
(`terraform-aws-jumphost` v6.1.0, `terraform-aws-openvpn` v10.2.0).

## Why this module matters more than the ones already done

AWS Inspector reports findings against a freshly launched instance before `unattended-upgrades` has run.
The finding closes on the next upgrade, but it has already **reopened its vulnerability group** by then, and
a group old enough to be reopened that way breaks the remediation SLA. The fix is to not present an
unpatched host to Inspector at all:

```
launch  -> instance tagged InspectorEc2Exclusion   (THIS MODULE)
boot    -> apt-get update && unattended-upgrade    (puppet-code, profile::boot_security_upgrade)
success -> aws ec2 delete-tags Key=InspectorEc2Exclusion
        -> Inspector's first findings describe a patched host
```

jumphost and openvpn each owned one service and one Puppet role. **website-pod is a shared library feeding
at least five roles**, and is the chokepoint for nearly all the remaining EC2 fleet:

| consumer | Puppet role | has `profile::boot_security_upgrade`? |
|---|---|---|
| `terraform-aws-ecs` (when `lb_type = "alb"`) | `ecsnode` | ✗ |
| `terraform-aws-elasticsearch` (**two** instantiations) | `elastic_master`, `elastic_data` | ✗ (postponed) |
| `terraform-aws-bookstack` | `bookstack` | ✗ (postponed) |
| `terraform-aws-openclaw` | `base` | ✗ |
| `terraform-aws-pmm-ecs` | via `terraform-aws-ecs` | ✗ |

(`http-redirect` and `tcp-pod` only mention website-pod in comments — not consumers.)

`terraform-aws-ecs` is the prize: it is the path to the ~40 ECS-managed ASGs in sandbox **and** to the
openvpn portal ASG that `terraform-aws-openvpn` deliberately left untagged.

## ⚠️ The constraint — and it inverts what the other two modules did

**The tag is fail-open.** An instance that launches tagged with nothing to remove the tag is **permanently
invisible to Inspector** — silently worse than never tagging.

In jumphost and openvpn the removal side was guaranteed present, so those modules tag unconditionally. Here
it is the opposite: **not one of the five roles above currently has the profile.** Tagging unconditionally
in a new website-pod version would take most of the EC2 fleet dark to Inspector the moment each consumer
bumped — the exact inverse of the goal.

So: **opt-in, default off, and a consumer flips it on only after its Puppet role has the profile.**

## Change 1 — the variable (`variables.tf`)

```hcl
variable "defer_inspector_findings_until_patched" {
  description = <<-EOT
    Tag instances with InspectorEc2Exclusion at launch, so Amazon Inspector does not
    report findings against them until Puppet has applied pending security updates and
    removed the tag.

    ONLY enable this if the instances' Puppet role includes
    profile::boot_security_upgrade. Nothing else removes the tag, and an instance that
    keeps it is excluded from Inspector permanently.
  EOT
  type        = bool
  default     = false
}
```

**On the name.** Not `inspector_exclusion_tag_enabled`: that reads permanent, and the whole point is that
the exclusion is temporary and self-reverting. `defer` plus `until_patched` carries both the temporariness
and the revert condition.

Also deliberately **not** `..._scan_...`. Per the Inspector docs, an excluded instance still gets scanned —
"the Amazon Inspector SSM plugin will continue to be invoked" — it is *finding creation* that is suppressed.
That distinction is the trap documented in `loopproof/docs/inspector-exclusion-reconciliation-lag.md`: during
the window an unassessed instance reports `ACTIVE / SUCCESSFUL / lastScannedAt=minutes ago / 0 findings`,
indistinguishable from genuinely clean. Naming the variable after "scan" would bake that wrong model into
every consumer's tfvars.

## Change 2 — the tag (`asg.tf`)

The ASG builds its tags from a single `dynamic "tag"` over `local.default_asg_tags` (~line 70). Add a
separate static block rather than widening that map:

```hcl
  # Suppresses Inspector findings until profile::boot_security_upgrade has applied
  # pending security updates and removed this tag. Opt-in because website-pod serves
  # roles that do not run that profile -- see
  # .claude/plans/inspector-findings-deferral.md. Consumers must also grant
  # ec2:DeleteTags via instance_profile_permissions, or the instance is excluded forever.
  dynamic "tag" {
    for_each = var.defer_inspector_findings_until_patched ? [1] : []
    content {
      key                 = "InspectorEc2Exclusion"
      value               = "true"
      propagate_at_launch = true
    }
  }
```

Inspector keys off the tag **key**; the value is ignored and the key is case-insensitive. jumphost uses
`true`, actions-runner uses `bootstrapping`.

It must be an **ASG** tag with `propagate_at_launch`, not a launch-template `tag_specifications` entry —
only the ASG path gives the tag-at-launch / delete-on-instance cycle the removal depends on.

### Why not just route it through `var.tags`

`var.tags` does reach instances — `var.tags` → `local.default_module_tags` → `local.default_asg_tags` →
`propagate_at_launch = true`. But `default_module_tags` is also applied to the ALB, the S3 access-log
buckets, every security group, the CloudWatch alarms, Glue, ACM and IAM. That stamps
`InspectorEc2Exclusion` on an S3 bucket, which is meaningless and will need explaining forever. `var.tags`
is a data channel, not a feature switch.

## What each consumer still has to do

website-pod supplies only the tag. The consumer supplies the removal permission, through the existing
`instance_profile_permissions` input — **no website-pod change needed for the IAM half**:

```hcl
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
      values   = [<the ASG name>]
    }
  }
```

`var.asg_name` (input) and `asg_name` (output) both exist for the ASG-name condition. Use a value known
**before** the ASG resource — openvpn used `local.asg_name` for exactly this reason, because referencing
`aws_autoscaling_group.*.name` would order the grant after the ASG has already begun launching tagged
instances. The `asg_name` *output* has that hazard; prefer the consumer's own local.

## Already in our favour

- **`instance_metadata_tags = "enabled"`** is already set on the launch template (`asg.tf` ~line 101). So the
  conclusive "was the tag actually set?" check is free for every website-pod consumer via
  `GET /latest/meta-data/tags/instance/InspectorEc2Exclusion` — no `ec2:DescribeTags` needed. `delete-tags`
  ignores a missing key, so without this the Puppet log says "removed" whether or not a tag existed.
- **`instance_profile_permissions`** already exists, so IAM is entirely caller-side.
- **`var.asg_name` / `asg_name` output** already exist for scoping.

## Gotchas

- **`instance_refresh { triggers = ["tag"] }`** (`asg.tf` ~line 22) — flipping the flag **triggers a rolling
  instance refresh** in that consumer. Not a no-op apply. For elasticsearch that is a cluster-wide roll.
- **elasticsearch instantiates website-pod twice** (`main.tf` lines ~113 and ~196, master and data). Both
  need the flag, and both roles need the Puppet profile, or half the cluster goes dark.
- **The non-ALB ECS path does not use this module.** `terraform-aws-ecs` picks website-pod only when
  `lb_type = "alb"`; otherwise it uses `tcp-pod`, which does **not** set `instance_metadata_tags` and needs
  the same treatment separately. Enabling this in `terraform-aws-ecs` covers only half its footprint.
- **Consumers are on mixed versions** — bookstack/ecs/elasticsearch on 6.4.0, openclaw on 5.17.0, pmm-ecs on
  5.10.0. The older two need a bump before they can opt in.

## Adoption order

Puppet role first, then the module bump, then the flag, then the IAM statement. Per consumer:

1. **`terraform-aws-ecs` / `role::ecsnode`** — biggest coverage, and it closes the openvpn portal gap that
   `terraform-aws-openvpn` explicitly left open. Note the `tcp-pod` half is not covered.
2. **`terraform-aws-elasticsearch` / `elastic_master`, `elastic_data`** — needs its own decision first: those
   roles deliberately suppress automatic service restarts and carry an apt.conf.d blacklist, so boot-time
   patching is a behaviour change, not just a tag.
3. **`terraform-aws-bookstack` / `role::bookstack`** — postponed on its own merits: a rarely-replaced
   singleton gets the benefit almost never while carrying the fail-open exposure continuously, and the
   cohort-relative detector in the loopproof doc is blind on a singleton (it needs a same-AMI sibling with
   findings > 0).
4. **`terraform-aws-openclaw` / `role::base`** — note this one runs the bare `base` role, so adding the
   profile there would reach every consumer of `role::base`, not just openclaw. Check that first.

## Checklist (this module only)

- [x] `variables.tf` — `defer_inspector_findings_until_patched`
- [x] `asg.tf` — conditional `dynamic "tag"` block
- [x] `make format` / `make lint`
- [x] `tests/` — on case in `tests/test_asg_name.py` (flag on: ASG tag present with `PropagateAtLaunch`, and
      the launched instances carry it); off case in `tests/test_create_lb.py` (default: absent from both the
      ASG and the instance). Both ride existing applies — no extra infrastructure spin-up. The root module
      `test_data/test_create_lb` gained a pass-through variable.
- [x] `terraform-docs` regen, plus a consumer-facing section in `README.md` and `docs/configuration.md`
      carrying the `ec2:DeleteTags` statement.
- [ ] `bumpversion minor` + CHANGELOG. Minor, not patch — new input, default preserves current behaviour.
      Not run: it commits, tags and pushes.

## Expected behaviour once a consumer opts in

Per `loopproof/docs/inspector-exclusion-reconciliation-lag.md`: scans resume immediately after the tag is
removed, but **findings take ~1.5–2h of running time** to appear. Measure with `firstObservedAt`, not
`lastScannedAt`. One prod jumphost never reconciled at all (13h16m, 0 findings, unexplained) — so consumers
with more than one instance are preferable early adopters, since the proposed cohort detector needs a
same-AMI sibling to compare against.
