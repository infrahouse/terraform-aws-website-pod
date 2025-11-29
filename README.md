# terraform-aws-website-pod

The module creates resources to run an HTTP service in an autoscaling group.
It creates a load balancer that terminates SSL on the TCP port 443.
It also issues the SSL certificate in ACM.

> **Note**: Starting from version 2.0 the module separates the main aws provider and a provider for
> Route53 resources. If you don't need to separate them, just pass the same provider for `aws` and `aws.dns`
> ```hcl
> providers = {
>   aws     = aws
>   aws.dns = aws
> }
> ```

## Usage

```hcl
module "website" {
  providers = {
    aws     = aws.aws-uw1
    aws.dns = aws.aws-uw1
  }
  source                = "infrahouse/website-pod/aws"
  version               = "5.10.0"
  environment           = var.environment
  ami                   = data.aws_ami.ubuntu_22.image_id
  backend_subnets       = module.website-vpc.subnet_private_ids
  zone_id               = "Z07662251LH3YRF2ERM3G"
  dns_a_records         = ["", "www"]
  internet_gateway_id   = module.website-vpc.internet_gateway_id
  key_pair_name         = data.aws_key_pair.aleks.key_name
  subnets               = module.website-vpc.subnet_public_ids
  userdata              = module.webserver_userdata.userdata
  stickiness_enabled    = true
}
```

### Security groups

The module used default security groups up until version 2.5.0.

Starting from the version 2.6.0 the behavior changes, however in a backward-compatible manner.
The module creates two security groups. One for the load balancer, another - for the backend instances.

The load balancer security group allows traffic to TCP ports 443 and `var.alb_listener_port` (80 by default).
By default, traffic is allowed from any source (0.0.0.0/0), but this can be restricted using `var.alb_ingress_cidr_blocks`.

The backend security group allows user traffic and health checks coming from the load balancer.
Also, the security group allows SSH from the VPC where the backend instances reside and from `var.ssh_cidr_block`.
It is 0.0.0.0/0 by default, but the goal is allow user restrict access let's say to anyone but the management VPC.

Both security groups allow incoming ICMP traffic.

Additionally, the user can specify additional security groups via `var.extra_security_groups_backend`.
They will be added to the backend instance alongside with the created backend security group.

### Using spot instances

By default, the module launches on-demand instances only. However, if you specify `var.on_demand_base_capacity`,
the ASG will fulfill its capacity by as many on-demand instances as `var.on_demand_base_capacity` and the rest will
be spot instances.

### Certificate Authority Authorization (CAA) Records

The module automatically creates CAA records for each DNS A record to control which certificate authorities can issue certificates for your domain. By default, only Amazon (ACM) is allowed to issue certificates.

To allow additional certificate authorities, use the `certificate_issuers` variable:

```hcl
module "website" {
  # ... other configuration ...

  # Allow both Amazon and Let's Encrypt to issue certificates
  certificate_issuers = ["amazon.com", "letsencrypt.org"]
}
```

The module automatically formats these domains into proper CAA records and adds a wildcard certificate blocking record (`0 issuewild ";"`) for security.

### Restricting ALB Access

By default, the load balancer accepts traffic from any source (0.0.0.0/0).
You can restrict access to specific CIDR ranges using the `alb_ingress_cidr_blocks` variable:

```hcl
module "website" {
  # ... other configuration ...

  # Allow access only from specific networks
  alb_ingress_cidr_blocks = [
    "10.0.0.0/8",      # Internal corporate network
    "203.0.113.0/24"   # Specific external IP range
  ]
}
```

This creates separate security group rules for each CIDR block, allowing fine-grained control over
who can access your load balancer on both HTTP (port 80/`var.alb_listener_port`) and HTTPS (port 443).

### ALB Access Logging (Security Best Practice)

**Recommended:** Enable ALB access logging for security investigations, incident response, debugging, and compliance requirements.

```hcl
module "website" {
  # ... other configuration ...

  # Enable access logging (recommended for production)
  alb_access_log_enabled = true
}
```

When enabled, the module creates an encrypted, versioned S3 bucket that stores detailed ALB access logs. These logs are essential for:
- **Security:** Track unauthorized access attempts and identify suspicious traffic patterns
- **Compliance:** Meet SOC2, HIPAA, PCI-DSS, and ISO 27001 requirements
- **Operations:** Debug production issues and analyze traffic patterns
- **AWS Best Practices:** Aligns with AWS Well-Architected Framework security pillar

**Cost Impact:** Minimal (~$4/year for moderate traffic). Storage costs are negligible compared to security and compliance benefits.

**Note:** Starting in v6.0.0, access logging will be enabled by default. See `variables.tf` for details.

## Deprecated Variables

The following variables contain typos and are deprecated. They will be removed in **v6.0.0**.

| Deprecated Variable (v5.x)          | Correct Variable (Use This)          | Status                    |
|-------------------------------------|--------------------------------------|---------------------------|
| `alb_healthcheck_uhealthy_threshold`| `alb_healthcheck_unhealthy_threshold`| ⚠️  Deprecated in v5.11.0 |
| `attach_tagret_group_to_asg`        | `attach_target_group_to_asg`         | ⚠️  Deprecated in v5.11.0 |

### Migration Instructions

If you're using the deprecated variables, update your code before upgrading to v6.0.0:

**Before:**
```hcl
module "website" {
  source  = "infrahouse/website-pod/aws"
  version = "~> 5.0"

  alb_healthcheck_uhealthy_threshold = 3  # Typo: "uhealthy"
  attach_tagret_group_to_asg         = true  # Typo: "tagret"
}
```

**After:**
```hcl
module "website" {
  source  = "infrahouse/website-pod/aws"
  version = "~> 5.11"  # or "~> 6.0" when available

  alb_healthcheck_unhealthy_threshold = 3  # Correct spelling
  attach_target_group_to_asg          = true  # Correct spelling
}
```

For detailed migration guidance, see [UPGRADE-6.0.md](UPGRADE-6.0.md).

<!-- BEGIN_TF_DOCS -->

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.11, < 7.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.6 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.23.0 |
| <a name="provider_aws.dns"></a> [aws.dns](#provider\_aws.dns) | 6.23.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_instance_profile"></a> [instance\_profile](#module\_instance\_profile) | registry.infrahouse.com/infrahouse/instance-profile/aws | 1.9.0 |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_alb.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/alb) | resource |
| [aws_alb_listener.redirect_to_ssl](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/alb_listener) | resource |
| [aws_alb_listener_rule.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/alb_listener_rule) | resource |
| [aws_alb_target_group.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/alb_target_group) | resource |
| [aws_autoscaling_group.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_autoscaling_lifecycle_hook.launching](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_lifecycle_hook) | resource |
| [aws_autoscaling_lifecycle_hook.terminating](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_lifecycle_hook) | resource |
| [aws_autoscaling_policy.cpu_load](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_policy) | resource |
| [aws_cloudwatch_metric_alarm.cpu_utilization_alarm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_launch_template.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_lb_listener.ssl](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_route53_record.cert_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.extra](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.extra_caa_amazon](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_s3_bucket.access_log](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_policy.access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.public_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.access_log](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.access_log](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_security_group.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.backend](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.alb_outgoing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.backend_outgoing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.alb_icmp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.alb_listener_port](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.backend_healthcheck](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.backend_icmp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.backend_ssh_input](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.backend_ssh_local](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.backend_user_traffic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [random_string.profile_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_ami.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_default_tags.provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/default_tags) | data source |
| [aws_ec2_instance_type.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ec2_instance_type) | data source |
| [aws_iam_policy_document.access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.default_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_route53_zone.webserver_zone](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [aws_subnet.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_vpc.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alb_access_log_enabled"></a> [alb\_access\_log\_enabled](#input\_alb\_access\_log\_enabled) | Whether to enable ALB access logging to S3.<br/><br/>**Security Best Practice:** Enabling access logs is recommended for:<br/>- Security investigations and incident response<br/>- Debugging production issues<br/>- Compliance requirements (SOC2, HIPAA, PCI-DSS)<br/>- AWS Well-Architected Framework best practices<br/><br/>When enabled, creates an encrypted, versioned S3 bucket for access logs.<br/>Storage costs are minimal compared to security and operational benefits.<br/><br/>**Note:** In v6.0.0, this will default to `true` (enabled by default).<br/>See UPGRADE-6.0.md for details. | `bool` | `false` | no |
| <a name="input_alb_access_log_force_destroy"></a> [alb\_access\_log\_force\_destroy](#input\_alb\_access\_log\_force\_destroy) | Destroy S3 bucket with access logs even if non-empty | `bool` | `false` | no |
| <a name="input_alb_healthcheck_enabled"></a> [alb\_healthcheck\_enabled](#input\_alb\_healthcheck\_enabled) | Whether health checks are enabled. | `bool` | `true` | no |
| <a name="input_alb_healthcheck_healthy_threshold"></a> [alb\_healthcheck\_healthy\_threshold](#input\_alb\_healthcheck\_healthy\_threshold) | Number of times the host have to pass the test to be considered healthy | `number` | `2` | no |
| <a name="input_alb_healthcheck_interval"></a> [alb\_healthcheck\_interval](#input\_alb\_healthcheck\_interval) | Number of seconds between checks | `number` | `5` | no |
| <a name="input_alb_healthcheck_path"></a> [alb\_healthcheck\_path](#input\_alb\_healthcheck\_path) | Path on the webserver that the elb will check to determine whether the instance is healthy or not | `string` | `"/index.html"` | no |
| <a name="input_alb_healthcheck_port"></a> [alb\_healthcheck\_port](#input\_alb\_healthcheck\_port) | Port of the webserver that the elb will check to determine whether the instance is healthy or not | `any` | `80` | no |
| <a name="input_alb_healthcheck_protocol"></a> [alb\_healthcheck\_protocol](#input\_alb\_healthcheck\_protocol) | Protocol to use with the webserver that the elb will check to determine whether the instance is healthy or not | `string` | `"HTTP"` | no |
| <a name="input_alb_healthcheck_response_code_matcher"></a> [alb\_healthcheck\_response\_code\_matcher](#input\_alb\_healthcheck\_response\_code\_matcher) | Range of http return codes that can match | `string` | `"200-299"` | no |
| <a name="input_alb_healthcheck_timeout"></a> [alb\_healthcheck\_timeout](#input\_alb\_healthcheck\_timeout) | Number of seconds to timeout a check | `number` | `4` | no |
| <a name="input_alb_healthcheck_uhealthy_threshold"></a> [alb\_healthcheck\_uhealthy\_threshold](#input\_alb\_healthcheck\_uhealthy\_threshold) | ⚠️  DEPRECATED - Contains typo, use 'alb\_healthcheck\_unhealthy\_threshold' instead.<br/>This variable will be removed in v6.0.0. See deprecations.tf for details.<br/>Number of times the host must fail the test to be considered unhealthy. | `number` | `null` | no |
| <a name="input_alb_healthcheck_unhealthy_threshold"></a> [alb\_healthcheck\_unhealthy\_threshold](#input\_alb\_healthcheck\_unhealthy\_threshold) | Number of consecutive health check failures required before considering the target unhealthy | `number` | `2` | no |
| <a name="input_alb_idle_timeout"></a> [alb\_idle\_timeout](#input\_alb\_idle\_timeout) | The time in seconds that the connection is allowed to be idle. | `number` | `60` | no |
| <a name="input_alb_ingress_cidr_blocks"></a> [alb\_ingress\_cidr\_blocks](#input\_alb\_ingress\_cidr\_blocks) | List of CIDR blocks allowed to access the ALB. Defaults to allow all (0.0.0.0/0). | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_alb_listener_port"></a> [alb\_listener\_port](#input\_alb\_listener\_port) | TCP port that a load balancer listens to to serve client HTTP requests. The load balancer redirects this port to 443 and HTTPS. | `number` | `80` | no |
| <a name="input_alb_name_prefix"></a> [alb\_name\_prefix](#input\_alb\_name\_prefix) | Name prefix for the load balancer | `string` | `"web"` | no |
| <a name="input_ami"></a> [ami](#input\_ami) | Image for EC2 instances | `string` | n/a | yes |
| <a name="input_asg_lifecycle_hook_heartbeat_timeout"></a> [asg\_lifecycle\_hook\_heartbeat\_timeout](#input\_asg\_lifecycle\_hook\_heartbeat\_timeout) | How much time in seconds to wait until the hook is completed before proceeding with the default action. | `number` | `3600` | no |
| <a name="input_asg_lifecycle_hook_initial"></a> [asg\_lifecycle\_hook\_initial](#input\_asg\_lifecycle\_hook\_initial) | Name for an initial LAUNCHING lifecycle hook configured via the initial\_lifecycle\_hook<br/>block in the ASG. This hook is evaluated during ASG creation.<br/>Only one initial hook is allowed per ASG.<br/><br/>Use this for simple lifecycle hooks that don't require additional configuration. | `string` | `null` | no |
| <a name="input_asg_lifecycle_hook_launching"></a> [asg\_lifecycle\_hook\_launching](#input\_asg\_lifecycle\_hook\_launching) | Name for a LAUNCHING lifecycle hook configured via a separate<br/>aws\_autoscaling\_lifecycle\_hook resource. This allows for more complex configurations<br/>and can be created after the ASG exists.<br/><br/>Use this if you need to attach SNS notifications or additional settings to the lifecycle hook. | `string` | `null` | no |
| <a name="input_asg_lifecycle_hook_launching_default_result"></a> [asg\_lifecycle\_hook\_launching\_default\_result](#input\_asg\_lifecycle\_hook\_launching\_default\_result) | Default result for launching lifecycle hook. | `string` | `"ABANDON"` | no |
| <a name="input_asg_lifecycle_hook_terminating"></a> [asg\_lifecycle\_hook\_terminating](#input\_asg\_lifecycle\_hook\_terminating) | Create a TERMINATING lifecycle hook with this name. | `string` | `null` | no |
| <a name="input_asg_lifecycle_hook_terminating_default_result"></a> [asg\_lifecycle\_hook\_terminating\_default\_result](#input\_asg\_lifecycle\_hook\_terminating\_default\_result) | Default result for terminating lifecycle hook. | `string` | `"ABANDON"` | no |
| <a name="input_asg_max_healthy_percentage"></a> [asg\_max\_healthy\_percentage](#input\_asg\_max\_healthy\_percentage) | Specifies the upper limit on the number of instances that are in the InService or Pending state with a healthy status during an instance replacement activity. | `number` | `200` | no |
| <a name="input_asg_max_size"></a> [asg\_max\_size](#input\_asg\_max\_size) | Maximum number of instances in ASG | `number` | `10` | no |
| <a name="input_asg_min_elb_capacity"></a> [asg\_min\_elb\_capacity](#input\_asg\_min\_elb\_capacity) | Terraform will wait until this many EC2 instances in the autoscaling group become healthy. By default, it's equal to var.asg\_min\_size. | `number` | `null` | no |
| <a name="input_asg_min_healthy_percentage"></a> [asg\_min\_healthy\_percentage](#input\_asg\_min\_healthy\_percentage) | Specifies the lower limit on the number of instances that must be in the InService state with a healthy status during an instance replacement activity. | `number` | `100` | no |
| <a name="input_asg_min_size"></a> [asg\_min\_size](#input\_asg\_min\_size) | Minimum number of instances in ASG | `number` | `2` | no |
| <a name="input_asg_name"></a> [asg\_name](#input\_asg\_name) | Autoscaling group name, if provided. | `string` | `null` | no |
| <a name="input_asg_scale_in_protected_instances"></a> [asg\_scale\_in\_protected\_instances](#input\_asg\_scale\_in\_protected\_instances) | Behavior when encountering instances protected from scale in are found. Available behaviors are Refresh, Ignore, and Wait. | `string` | `"Ignore"` | no |
| <a name="input_assume_dns"></a> [assume\_dns](#input\_assume\_dns) | If True, create DNS records provided by var.dns\_a\_records. | `bool` | `true` | no |
| <a name="input_attach_tagret_group_to_asg"></a> [attach\_tagret\_group\_to\_asg](#input\_attach\_tagret\_group\_to\_asg) | ⚠️  DEPRECATED - Contains typo, use 'attach\_target\_group\_to\_asg' instead.<br/>This variable will be removed in v6.0.0. See deprecations.tf for details.<br/>Whether to register ASG instances in the target group. Disable if using ECS which registers targets itself. | `bool` | `null` | no |
| <a name="input_attach_target_group_to_asg"></a> [attach\_target\_group\_to\_asg](#input\_attach\_target\_group\_to\_asg) | Whether to register ASG instances in the target group. Disable if using ECS which registers targets itself. | `bool` | `true` | no |
| <a name="input_autoscaling_target_cpu_load"></a> [autoscaling\_target\_cpu\_load](#input\_autoscaling\_target\_cpu\_load) | Target CPU load for autoscaling | `number` | `60` | no |
| <a name="input_backend_subnets"></a> [backend\_subnets](#input\_backend\_subnets) | Subnet ids where EC2 instances should be present | `list(string)` | n/a | yes |
| <a name="input_certificate_issuers"></a> [certificate\_issuers](#input\_certificate\_issuers) | List of certificate authority domains allowed to issue certificates for this domain (e.g., ["amazon.com", "letsencrypt.org"]). The module will format these as CAA records. | `list(string)` | <pre>[<br/>  "amazon.com"<br/>]</pre> | no |
| <a name="input_dns_a_records"></a> [dns\_a\_records](#input\_dns\_a\_records) | List of A records in the zone\_id that will resolve to the ALB dns name. | `list(string)` | <pre>[<br/>  ""<br/>]</pre> | no |
| <a name="input_enable_deletion_protection"></a> [enable\_deletion\_protection](#input\_enable\_deletion\_protection) | Prevent load balancer from destroying | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Name of environment | `string` | `"development"` | no |
| <a name="input_extra_security_groups_backend"></a> [extra\_security\_groups\_backend](#input\_extra\_security\_groups\_backend) | A list of security group ids to assign to backend instances | `list(string)` | `[]` | no |
| <a name="input_health_check_grace_period"></a> [health\_check\_grace\_period](#input\_health\_check\_grace\_period) | ASG will wait up to this number of seconds for instance to become healthy | `number` | `600` | no |
| <a name="input_health_check_type"></a> [health\_check\_type](#input\_health\_check\_type) | Type of healthcheck the ASG uses. Can be EC2 or ELB. | `string` | `"ELB"` | no |
| <a name="input_instance_profile_permissions"></a> [instance\_profile\_permissions](#input\_instance\_profile\_permissions) | A JSON policy document to attach to the instance profile.<br/>This should be the output of an aws\_iam\_policy\_document data source.<br/><br/>Example:<br/>  instance\_profile\_permissions = data.aws\_iam\_policy\_document.my\_policy.json<br/><br/>If not specified, defaults to a minimal policy allowing sts:GetCallerIdentity. | `string` | `null` | no |
| <a name="input_instance_role_name"></a> [instance\_role\_name](#input\_instance\_role\_name) | If specified, the instance profile role will have this name. Otherwise, the role name will be generated. | `string` | `null` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instances type | `string` | `"t3.micro"` | no |
| <a name="input_internet_gateway_id"></a> [internet\_gateway\_id](#input\_internet\_gateway\_id) | Not used, but AWS Internet Gateway must be present. Ensure by passing its id. | `string` | n/a | yes |
| <a name="input_key_pair_name"></a> [key\_pair\_name](#input\_key\_pair\_name) | SSH keypair name to be deployed in EC2 instances | `string` | n/a | yes |
| <a name="input_max_instance_lifetime_days"></a> [max\_instance\_lifetime\_days](#input\_max\_instance\_lifetime\_days) | The maximum amount of time, in \_days\_, that an instance can be in service, values must be either equal to 0 or between 7 and 365 days. | `number` | `30` | no |
| <a name="input_min_healthy_percentage"></a> [min\_healthy\_percentage](#input\_min\_healthy\_percentage) | Amount of capacity in the Auto Scaling group that must remain healthy during an instance refresh to allow the operation to continue, as a percentage of the desired capacity of the Auto Scaling group. | `number` | `100` | no |
| <a name="input_on_demand_base_capacity"></a> [on\_demand\_base\_capacity](#input\_on\_demand\_base\_capacity) | If specified, the ASG will request spot instances and this will be the minimal number of on-demand instances. | `number` | `null` | no |
| <a name="input_protect_from_scale_in"></a> [protect\_from\_scale\_in](#input\_protect\_from\_scale\_in) | Whether newly launched instances are automatically protected from termination by Amazon EC2 Auto Scaling when scaling in. | `bool` | `false` | no |
| <a name="input_root_volume_size"></a> [root\_volume\_size](#input\_root\_volume\_size) | Root volume size in EC2 instance in Gigabytes | `number` | `30` | no |
| <a name="input_service_name"></a> [service\_name](#input\_service\_name) | Descriptive name of a service that will use this VPC | `string` | `"website"` | no |
| <a name="input_sns_topic_alarm_arn"></a> [sns\_topic\_alarm\_arn](#input\_sns\_topic\_alarm\_arn) | ARN of SNS topic for Cloudwatch alarms on base EC2 instance. | `string` | `null` | no |
| <a name="input_ssh_cidr_block"></a> [ssh\_cidr\_block](#input\_ssh\_cidr\_block) | CIDR range that is allowed to SSH into the backend instances.  Format is a.b.c.d/<prefix>. | `string` | `null` | no |
| <a name="input_stickiness_enabled"></a> [stickiness\_enabled](#input\_stickiness\_enabled) | If true, enable stickiness on the target group ensuring a clients is forwarded to the same target. | `bool` | `true` | no |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | Subnet ids where load balancer should be present | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources creatded by the module. | `map(string)` | `{}` | no |
| <a name="input_target_group_deregistration_delay"></a> [target\_group\_deregistration\_delay](#input\_target\_group\_deregistration\_delay) | Time in seconds for ALB to wait before deregistering a target.<br/>During this time, the target continues to receive existing connections<br/>but no new connections. This allows in-flight requests to complete.<br/><br/>Common use cases:<br/>- Reduce for faster deployments (e.g., 30s for stateless apps)<br/>- Increase for long-running requests (e.g., 600s for file uploads)<br/><br/>Valid range: 0-3600 seconds. AWS default is 300 seconds. | `number` | `300` | no |
| <a name="input_target_group_port"></a> [target\_group\_port](#input\_target\_group\_port) | TCP port that a target listens to to serve requests from the load balancer. | `number` | `80` | no |
| <a name="input_target_group_type"></a> [target\_group\_type](#input\_target\_group\_type) | Target group type: instance, ip, alb. Default is instance. | `string` | `"instance"` | no |
| <a name="input_upstream_module"></a> [upstream\_module](#input\_upstream\_module) | Module that called this module. | `string` | `null` | no |
| <a name="input_userdata"></a> [userdata](#input\_userdata) | userdata for cloud-init to provision EC2 instances | `string` | n/a | yes |
| <a name="input_vanta_contains_ephi"></a> [vanta\_contains\_ephi](#input\_vanta\_contains\_ephi) | This tag allows administrators to define whether or not a resource contains electronically Protected Health Information (ePHI). It can be set to either (true) or if they do not have ephi data (false). | `bool` | `false` | no |
| <a name="input_vanta_contains_user_data"></a> [vanta\_contains\_user\_data](#input\_vanta\_contains\_user\_data) | his tag allows administrators to define whether or not a resource contains user data (true) or if they do not contain user data (false). | `bool` | `false` | no |
| <a name="input_vanta_description"></a> [vanta\_description](#input\_vanta\_description) | This tag allows administrators to set a description, for instance, or add any other descriptive information. | `string` | `null` | no |
| <a name="input_vanta_no_alert"></a> [vanta\_no\_alert](#input\_vanta\_no\_alert) | Administrators can add this tag to mark a resource as out of scope for their audit. If this tag is added, the administrator will need to set a reason for why it's not relevant to their audit. | `string` | `null` | no |
| <a name="input_vanta_owner"></a> [vanta\_owner](#input\_vanta\_owner) | The email address of the instance's owner, and it should be set to the email address of a user in Vanta. An owner will not be assigned if there is no user in Vanta with the email specified. | `string` | `null` | no |
| <a name="input_vanta_production_environments"></a> [vanta\_production\_environments](#input\_vanta\_production\_environments) | Environment names to consider production grade in Vanta. | `list(string)` | <pre>[<br/>  "production",<br/>  "prod"<br/>]</pre> | no |
| <a name="input_vanta_user_data_stored"></a> [vanta\_user\_data\_stored](#input\_vanta\_user\_data\_stored) | This tag allows administrators to describe the type of user data the instance contains. | `string` | `null` | no |
| <a name="input_wait_for_capacity_timeout"></a> [wait\_for\_capacity\_timeout](#input\_wait\_for\_capacity\_timeout) | How much time to wait until all instances are healthy | `string` | `"20m"` | no |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | Domain name zone ID where the website will be available | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_acm_certificate_arn"></a> [acm\_certificate\_arn](#output\_acm\_certificate\_arn) | ARN of the ACM certificate used by the load balancer |
| <a name="output_alb_security_group_id"></a> [alb\_security\_group\_id](#output\_alb\_security\_group\_id) | ID of the ALB security group |
| <a name="output_asg_arn"></a> [asg\_arn](#output\_asg\_arn) | ARN of the created autoscaling group |
| <a name="output_asg_name"></a> [asg\_name](#output\_asg\_name) | Name of the created autoscaling group |
| <a name="output_backend_security_group"></a> [backend\_security\_group](#output\_backend\_security\_group) | Map with security group id and rules |
| <a name="output_backend_security_group_id"></a> [backend\_security\_group\_id](#output\_backend\_security\_group\_id) | ID of the backend instances security group |
| <a name="output_dns_name"></a> [dns\_name](#output\_dns\_name) | DNS name of the load balancer. |
| <a name="output_instance_profile_name"></a> [instance\_profile\_name](#output\_instance\_profile\_name) | EC2 instance profile name. |
| <a name="output_instance_role_arn"></a> [instance\_role\_arn](#output\_instance\_role\_arn) | ARN of the instance role. |
| <a name="output_instance_role_name"></a> [instance\_role\_name](#output\_instance\_role\_name) | Name of the instance role. |
| <a name="output_instance_role_policy_arn"></a> [instance\_role\_policy\_arn](#output\_instance\_role\_policy\_arn) | Policy ARN attached to EC2 instance profile. |
| <a name="output_instance_role_policy_attachment"></a> [instance\_role\_policy\_attachment](#output\_instance\_role\_policy\_attachment) | Policy attachment id. |
| <a name="output_instance_role_policy_name"></a> [instance\_role\_policy\_name](#output\_instance\_role\_policy\_name) | Policy name attached to EC2 instance profile. |
| <a name="output_load_balancer_arn"></a> [load\_balancer\_arn](#output\_load\_balancer\_arn) | Load Balancer ARN |
| <a name="output_load_balancer_dns_name"></a> [load\_balancer\_dns\_name](#output\_load\_balancer\_dns\_name) | Load balancer DNS name. |
| <a name="output_load_balancer_security_groups"></a> [load\_balancer\_security\_groups](#output\_load\_balancer\_security\_groups) | Security groups associated with the load balancer |
| <a name="output_ssl_listener_arn"></a> [ssl\_listener\_arn](#output\_ssl\_listener\_arn) | SSL listener ARN |
| <a name="output_target_group_arn"></a> [target\_group\_arn](#output\_target\_group\_arn) | Target group ARN that listens to the service port. |
| <a name="output_zone_id"></a> [zone\_id](#output\_zone\_id) | Zone id where A records are created for the service. |
<!-- END_TF_DOCS -->
