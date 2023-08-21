# terraform-aws-website-pod
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.11 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.11 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_webserver_profile"></a> [webserver\_profile](#module\_webserver\_profile) | infrahouse/instance-profile/aws | ~> 1.0 |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_alb.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/alb) | resource |
| [aws_alb_listener.redirect_to_ssl](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/alb_listener) | resource |
| [aws_alb_target_group.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/alb_target_group) | resource |
| [aws_autoscaling_group.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_autoscaling_policy.cpu_load](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_policy) | resource |
| [aws_launch_template.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_lb_listener.ssl](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_route53_record.cert_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.extra](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_route53_zone.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [aws_subnet.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |

## Inputs

| Name | Description | Type | Default                      | Required |
|------|-------------|------|------------------------------|:--------:|
| <a name="input_alb_healthcheck_healthy_threshold"></a> [alb\_healthcheck\_healthy\_threshold](#input\_alb\_healthcheck\_healthy\_threshold) | Number of times the host have to pass the test to be considered healthy | `number` | `2`                          | no |
| <a name="input_alb_healthcheck_interval"></a> [alb\_healthcheck\_interval](#input\_alb\_healthcheck\_interval) | Number of seconds between checks | `number` | `5`                          | no |
| <a name="input_alb_healthcheck_path"></a> [alb\_healthcheck\_path](#input\_alb\_healthcheck\_path) | Path on the webserver that the elb will check to determine whether the instance is healthy or not | `string` | `"/index.html"`              | no |
| <a name="input_alb_healthcheck_port"></a> [alb\_healthcheck\_port](#input\_alb\_healthcheck\_port) | Port of the webserver that the elb will check to determine whether the instance is healthy or not | `string` | `"80"`                       | no |
| <a name="input_alb_healthcheck_protocol"></a> [alb\_healthcheck\_protocol](#input\_alb\_healthcheck\_protocol) | Protocol to use with the webserver that the elb will check to determine whether the instance is healthy or not | `string` | `"HTTP"`                     | no |
| <a name="input_alb_healthcheck_response_code_matcher"></a> [alb\_healthcheck\_response\_code\_matcher](#input\_alb\_healthcheck\_response\_code\_matcher) | Range of http return codes that can match | `string` | `"200-299"`                  | no |
| <a name="input_alb_healthcheck_timeout"></a> [alb\_healthcheck\_timeout](#input\_alb\_healthcheck\_timeout) | Number of seconds to timeout a check | `number` | `4`                          | no |
| <a name="input_alb_healthcheck_uhealthy_threshold"></a> [alb\_healthcheck\_uhealthy\_threshold](#input\_alb\_healthcheck\_uhealthy\_threshold) | Number of times the host have to pass the test to be considered UNhealthy | `number` | `2`                          | no |
| <a name="input_ami"></a> [ami](#input\_ami) | Image for EC2 instances | `string` | n/a                          | yes |
| <a name="input_asg_max_size"></a> [asg\_max\_size](#input\_asg\_max\_size) | Maximum number of instances in ASG | `number` | `10`                         | no |
| <a name="input_asg_min_size"></a> [asg\_min\_size](#input\_asg\_min\_size) | Minimum number of instances in ASG | `number` | `2`                          | no |
| <a name="input_autoscaling_target_cpu_load"></a> [autoscaling\_target\_cpu\_load](#input\_autoscaling\_target\_cpu\_load) | Target CPU load for autoscaling | `number` | `60`                         | no |
| <a name="input_backend_subnets"></a> [backend\_subnets](#input\_backend\_subnets) | Subnet ids where EC2 instances should be present | `list(string)` | n/a                          | yes |
| <a name="input_dns_a_records_extra"></a> [dns\_a\_records\_extra](#input\_dns\_a\_records\_extra) | List of extra A records in the dns\_zone that will resolve to ALB dns name. | `list(string)` | <pre>[<br>  "www"<br>]</pre> | no |
| <a name="input_dns_zone"></a> [dns\_zone](#input\_dns\_zone) | Domain name zone where the website will be available | `string` | n/a                          | yes |
| <a name="input_enable_deletion_protection"></a> [enable\_deletion\_protection](#input\_enable\_deletion\_protection) | Prevent load balancer from destroying | `bool` | `false`                      | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Name of environment | `string` | `"development"`              | no |
| <a name="input_health_check_grace_period"></a> [health\_check\_grace\_period](#input\_health\_check\_grace\_period) | ASG will wait up to this number of seconds for instance to become healthy | `number` | `300`                        | no |
| <a name="input_health_check_type"></a> [health\_check\_type](#input\_health\_check\_type) | Type of healthcheck the ASG uses. Can be EC2 or ELB. | `string` | `"ELB"`                      | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instances type | `string` | `"t3.micro"`                 | no |
| <a name="input_internet_gateway_id"></a> [internet\_gateway\_id](#input\_internet\_gateway\_id) | AWS Internet Gateway must be present. Ensure by passing its id. | `string` | n/a                          | yes |
| <a name="input_key_pair_name"></a> [key\_pair\_name](#input\_key\_pair\_name) | SSH keypair name to be deployed in EC2 instances | `any` | n/a                          | yes |
| <a name="input_max_instance_lifetime_days"></a> [max\_instance\_lifetime\_days](#input\_max\_instance\_lifetime\_days) | The maximum amount of time, in \_days\_, that an instance can be in service, values must be either equal to 0 or between 7 and 365 days. | `number` | `30`                         | no |
| <a name="input_root_volume_size"></a> [root\_volume\_size](#input\_root\_volume\_size) | Root volume size in EC2 instance in Gigabytes | `number` | `30`                         | no |
| <a name="input_service_name"></a> [service\_name](#input\_service\_name) | Descriptive name of a service that will use this VPC | `string` | `"website"`                  | no |
| <a name="input_stickiness_enabled"></a> [stickiness\_enabled](#input\_stickiness\_enabled) | If true, enable stickiness on the target group ensuring a clients is forwarded to the same target. | `bool` | `false`                      | no |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | Subnet ids where load balancer should be present | `list(string)` | n/a                          | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to each resource | `map` | `{}`                         | no |
| <a name="input_userdata"></a> [userdata](#input\_userdata) | userdata for cloud-init to provision EC2 instances | `any` | n/a                          | yes |
| <a name="input_wait_for_capacity_timeout"></a> [wait\_for\_capacity\_timeout](#input\_wait\_for\_capacity\_timeout) | How much time to wait until all instances are healthy | `string` | `"20m"`                      | no |
| <a name="input_webserver_permissions"></a> [webserver\_permissions](#input\_webserver\_permissions) | A JSON with a permissions policy document. The policy will be attached to the webserver instance profile. | `string` | n/a                          | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_dns_name"></a> [dns\_name](#output\_dns\_name) | n/a |
| <a name="output_zone_id"></a> [zone\_id](#output\_zone\_id) | n/a |
