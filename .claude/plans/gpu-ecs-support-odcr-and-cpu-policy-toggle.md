# website-pod changes for GPU ECS autoscaling

**Module:** terraform-aws-website-pod (current v6.2.0)
**Requested by:** terraform-aws-ecs GPU-utilization-autoscaling work
**Related plan:** `terraform-aws-ecs/.claude/plans/gpu-utilization-autoscaling.md`
**Suggested bump:** minor — both changes default to current behavior

---

## Why

terraform-aws-ecs is adding native GPU-utilization autoscaling for GPU services
(vLLM on `g5.2xlarge`). Two things it needs are owned by **this** module (the ASG and
its launch template live here, not in terraform-aws-ecs), so they can't be done from
the consumer side:

1. **Bind the ASG to an On-Demand Capacity Reservation (ODCR)** so production keeps a
   minimum number of GPU instances — requires a launch-template
   `capacity_reservation_specification`, which this module does not expose today.
2. **Let the consumer turn off the ASG host-CPU scaling policy** (`cpu_load`). For an
   ECS capacity-provider-managed ASG, instance count is driven by ECS managed scaling
   (`CapacityProviderReservation`). The `cpu_load` policy (`ASGAverageCPUUtilization`)
   is a *second* controller on the same `DesiredCapacity` lever; on GPU hosts it
   launches instances ECS has no task for (host CPU can't be relieved by adding an
   instance — tasks don't migrate), which idle, dilute the CPU average, and fight
   managed scaling. AWS advises against a custom ASG policy alongside managed scaling.
   The consumer needs to disable it. (Full reasoning in the ecs-side plan, §1c.)

Both are opt-in and default to today's behavior, so existing consumers see no change.

---

## Change 1 — Launch-template capacity reservation (targeted ODCR)

**Today:** `aws_launch_template.website` (`asg.tf:83`) has no
`capacity_reservation_specification` block and there is no variable for it. Confirmed
by grep: no `capacity_reservation` string anywhere in the module.

**Add** a variable and a gated dynamic block:

```hcl
# variables.tf
variable "capacity_reservation_id" {
  description = "Optional On-Demand Capacity Reservation ID to target from the launch template. When set, instances launch into this reservation (instance_match_criteria = targeted)."
  type        = string
  default     = null
}

variable "capacity_reservation_resource_group_arn" {
  description = "Optional Capacity Reservation resource-group ARN to target (alternative to a single reservation ID)."
  type        = string
  default     = null
}
```

```hcl
# asg.tf, inside resource "aws_launch_template" "website"
dynamic "capacity_reservation_specification" {
  for_each = (var.capacity_reservation_id != null || var.capacity_reservation_resource_group_arn != null) ? [1] : []
  content {
    capacity_reservation_preference = "capacity-reservations-only" # or leave unset
    capacity_reservation_target {
      capacity_reservation_id                 = var.capacity_reservation_id
      capacity_reservation_resource_group_arn = var.capacity_reservation_resource_group_arn
    }
  }
}
```

Notes:
- Both vars default `null` → `for_each` empty → block absent → byte-identical launch
  template for existing consumers.
- Validate mutual exclusivity (id XOR resource-group ARN) in a `validation` block.
- Decide the `capacity_reservation_preference` default; AWS rejects setting
  `preference` and `target` together in some combinations — test both shapes.

---

## Change 2 — Make the `cpu_load` ASG policy optional

**Today:** `aws_autoscaling_policy.cpu_load` (`autoscaling.tf:1`) is created
**unconditionally** for every ASG, target `var.autoscaling_target_cpu_load` (default
60, `variables.tf:300`).

**Add** a toggle and gate the resource:

```hcl
# variables.tf
variable "create_cpu_scaling_policy" {
  description = "Whether to create the ASG host-CPU target-tracking policy (ASGAverageCPUUtilization). Set false when instance count is managed elsewhere (e.g. an ECS capacity provider's managed scaling), where a second ASG policy conflicts."
  type        = bool
  default     = true
}
```

```hcl
# autoscaling.tf
resource "aws_autoscaling_policy" "cpu_load" {
  count                  = var.create_cpu_scaling_policy ? 1 : 0
  autoscaling_group_name = aws_autoscaling_group.website.name
  ...
}
```

### Migration subtlety — needs a `moved` block

Adding `count` changes the resource address from `aws_autoscaling_policy.cpu_load` to
`aws_autoscaling_policy.cpu_load[0]`. Without a migration, existing states would
**destroy and recreate** the policy. Add to `moved.tf`:

```hcl
moved {
  from = aws_autoscaling_policy.cpu_load
  to   = aws_autoscaling_policy.cpu_load[0]
}
```

This is a no-op for consumers who keep the default (`true`).

### Related: the CPU alarm premise

`alarms.tf` derives a CPU alarm threshold from `autoscaling_target_cpu_load` on the
premise "CPU high → ASG launches instances; if it stays high, autoscaling failed"
(`variables.tf:894+`). When `create_cpu_scaling_policy = false`, that premise no
longer holds — the alarm would misfire/mislead. Decide whether to also gate or
reword that alarm when the policy is off. At minimum, note it; ideally gate it on the
same toggle.

---

## Consumer side (terraform-aws-ecs) — for reference

Once released, terraform-aws-ecs will:
- Pass `capacity_reservation_id` through from its own `gpu_capacity_reservation_id`
  variable (targeted-ODCR path).
- Set `create_cpu_scaling_policy = var.gpu_count == 0` (off for GPU services), so ECS
  managed scaling is the sole instance driver.

Until this ships, the ecs-side plan uses fallbacks: **open** ODCR (no launch-template
change) and neutralizing `cpu_load` by passing a never-fires target
(`autoscaling_target_cpu_load = 99` when `gpu_count > 0`). These changes replace both
fallbacks with the clean path.

---

## Checklist

- [ ] Add `capacity_reservation_id` / `capacity_reservation_resource_group_arn` vars
- [ ] Add gated `capacity_reservation_specification` dynamic block to the launch template
- [ ] Validate id XOR resource-group-ARN; test `capacity_reservation_preference` shapes
- [ ] Add `create_cpu_scaling_policy` var; gate `aws_autoscaling_policy.cpu_load` with `count`
- [ ] Add `moved` block for `cpu_load` → `cpu_load[0]`
- [ ] Decide/handle the CPU alarm when the policy is disabled
- [ ] Confirm defaults keep existing plans byte-identical (no-op for current consumers)
- [ ] Read `.claude/CODING_STANDARD.md` before writing code
- [ ] `terraform fmt -recursive`, `make validate`; minor version bump
