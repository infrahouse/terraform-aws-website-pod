variable "alb_access_log_enabled" {
  description = <<-EOF
    Whether to enable ALB access logging to S3.

    **Security Best Practice:** Enabling access logs is recommended for:
    - Security investigations and incident response
    - Debugging production issues
    - Compliance requirements (SOC2, HIPAA, PCI-DSS)
    - AWS Well-Architected Framework best practices

    When enabled, creates an encrypted, versioned S3 bucket for access logs.
    Storage costs are minimal compared to security and operational benefits.

    **Note:** In v6.0.0, this will default to `true` (enabled by default).
    See UPGRADE-6.0.md for details.
  EOF
  type        = bool
  default     = false
}

variable "alb_access_log_force_destroy" {
  description = "Destroy S3 bucket with access logs even if non-empty"
  type        = bool
  default     = false
}

variable "alb_healthcheck_enabled" {
  description = "Whether health checks are enabled."
  type        = bool
  default     = true
}
variable "alb_healthcheck_path" {
  description = "Path on the webserver that the elb will check to determine whether the instance is healthy or not"
  type        = string
  default     = "/index.html"
}

variable "alb_healthcheck_port" {
  description = "Port of the webserver that the elb will check to determine whether the instance is healthy or not"
  type        = any
  default     = 80
}

variable "alb_healthcheck_protocol" {
  description = "Protocol to use with the webserver that the elb will check to determine whether the instance is healthy or not"
  type        = string
  default     = "HTTP"
}

variable "alb_healthcheck_healthy_threshold" {
  description = "Number of times the host have to pass the test to be considered healthy"
  type        = number
  default     = 2
}

variable "alb_healthcheck_uhealthy_threshold" {
  description = <<-EOF
    ⚠️  DEPRECATED - Contains typo, use 'alb_healthcheck_unhealthy_threshold' instead.
    This variable will be removed in v6.0.0. See deprecations.tf for details.
    Number of times the host must fail the test to be considered unhealthy.
  EOF
  type        = number
  default     = null
}

variable "alb_healthcheck_unhealthy_threshold" {
  description = "Number of consecutive health check failures required before considering the target unhealthy"
  type        = number
  default     = 2
}

variable "alb_healthcheck_interval" {
  description = "Number of seconds between checks"
  type        = number
  default     = 5
}

variable "alb_healthcheck_timeout" {
  description = "Number of seconds to timeout a check"
  type        = number
  default     = 4
}

variable "alb_healthcheck_response_code_matcher" {
  description = "Range of http return codes that can match"
  type        = string
  default     = "200-299"
}
variable "alb_idle_timeout" {
  description = "The time in seconds that the connection is allowed to be idle."
  type        = number
  default     = 60
}

variable "alb_listener_port" {
  description = "TCP port that a load balancer listens to to serve client HTTP requests. The load balancer redirects this port to 443 and HTTPS."
  type        = number
  default     = 80
}

variable "alb_name_prefix" {
  description = "Name prefix for the load balancer"
  type        = string
  default     = "web"
}

variable "alb_ingress_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the ALB. Defaults to allow all (0.0.0.0/0)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ami" {
  description = "Image for EC2 instances"
  type        = string
}

variable "assume_dns" {
  description = "If True, create DNS records provided by var.dns_a_records."
  type        = bool
  default     = true
}

variable "min_healthy_percentage" {
  description = "Amount of capacity in the Auto Scaling group that must remain healthy during an instance refresh to allow the operation to continue, as a percentage of the desired capacity of the Auto Scaling group."
  type        = number
  default     = 100
}

variable "asg_lifecycle_hook_initial" {
  description = "Create a LAUNCHING initial lifecycle hook with this name."
  type        = string
  default     = null
}

variable "asg_lifecycle_hook_launching" {
  description = "Create a LAUNCHING lifecycle hook with this name."
  type        = string
  default     = null
}

variable "asg_lifecycle_hook_launching_default_result" {
  description = "Default result for launching lifecycle hook."
  type        = string
  default     = "ABANDON"
}

variable "asg_lifecycle_hook_terminating" {
  description = "Create a TERMINATING lifecycle hook with this name."
  type        = string
  default     = null
}

variable "asg_lifecycle_hook_terminating_default_result" {
  description = "Default result for terminating lifecycle hook."
  type        = string
  default     = "ABANDON"
}

variable "asg_lifecycle_hook_heartbeat_timeout" {
  description = "How much time in seconds to wait until the hook is completed before proceeding with the default action."
  type        = number
  default     = 3600
}


variable "asg_min_elb_capacity" {
  description = "Terraform will wait until this many EC2 instances in the autoscaling group become healthy. By default, it's equal to var.asg_min_size."
  type        = number
  default     = null
}

variable "asg_min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 10
}
variable "asg_min_healthy_percentage" {
  description = "Specifies the lower limit on the number of instances that must be in the InService state with a healthy status during an instance replacement activity."
  type        = number
  default     = 100
}

variable "asg_max_healthy_percentage" {
  description = "Specifies the upper limit on the number of instances that are in the InService or Pending state with a healthy status during an instance replacement activity."
  type        = number
  default     = 200

}

variable "asg_name" {
  description = "Autoscaling group name, if provided."
  type        = string
  default     = null
}

variable "asg_scale_in_protected_instances" {
  description = "Behavior when encountering instances protected from scale in are found. Available behaviors are Refresh, Ignore, and Wait."
  type        = string
  default     = "Ignore"
}

variable "autoscaling_target_cpu_load" {
  description = "Target CPU load for autoscaling"
  default     = 60
  type        = number
}

variable "backend_subnets" {
  description = "Subnet ids where EC2 instances should be present"
  type        = list(string)
}

# "A" records in a hosted zone, specified by zone_id
# If the zone is infrahouse.com and the "A" records ["www"], then the module
# will create records (and a certificate for):
# - www.infrahouse.com
# To create the A record for infrahouse.com, pass an empty string:
# ["", "www"]
# If we pass A records as ["something"] then the module
# will create the "A" record something.infrahouse.com
variable "dns_a_records" {
  description = "List of A records in the zone_id that will resolve to the ALB dns name."
  type        = list(string)
  default     = [""]
}

variable "enable_deletion_protection" {
  description = "Prevent load balancer from destroying"
  type        = bool
  default     = false
}

variable "environment" {
  description = "Name of environment"
  type        = string
  default     = "development"
}

variable "extra_security_groups_backend" {
  description = "A list of security group ids to assign to backend instances"
  type        = list(string)
  default     = []
}

variable "instance_role_name" {
  description = "If specified, the instance profile role will have this name. Otherwise, the role name will be generated."
  type        = string
  default     = null
}

variable "instance_profile_permissions" {
  description = "A JSON with a permissions policy document. The policy will be attached to the instance profile."
  type        = string
  default     = null
}


variable "instance_type" {
  description = "EC2 instances type"
  type        = string
  default     = "t3.micro"
}

variable "internet_gateway_id" { # tflint-ignore: terraform_unused_declarations
  description = "Not used, but AWS Internet Gateway must be present. Ensure by passing its id."
  type        = string
}

variable "health_check_grace_period" {
  description = "ASG will wait up to this number of seconds for instance to become healthy"
  type        = number
  default     = 600
}

variable "health_check_type" {
  # Good summary
  # https://stackoverflow.com/questions/42466157/whats-the-difference-between-elb-health-check-and-ec2-health-check
  description = "Type of healthcheck the ASG uses. Can be EC2 or ELB."
  type        = string
  default     = "ELB"
}

variable "key_pair_name" {
  description = "SSH keypair name to be deployed in EC2 instances"
  type        = string
}

variable "max_instance_lifetime_days" {
  description = "The maximum amount of time, in _days_, that an instance can be in service, values must be either equal to 0 or between 7 and 365 days."
  type        = number
  default     = 30
}

variable "protect_from_scale_in" {
  description = "Whether newly launched instances are automatically protected from termination by Amazon EC2 Auto Scaling when scaling in."
  type        = bool
  default     = false
}

variable "root_volume_size" {
  description = "Root volume size in EC2 instance in Gigabytes"
  type        = number
  default     = 30
  nullable    = false
}
variable "service_name" {
  description = "Descriptive name of a service that will use this VPC"
  type        = string
  default     = "website"
}

variable "on_demand_base_capacity" {
  description = "If specified, the ASG will request spot instances and this will be the minimal number of on-demand instances."
  type        = number
  default     = null
}

variable "ssh_cidr_block" {
  description = "CIDR range that is allowed to SSH into the backend instances.  Format is a.b.c.d/<prefix>."
  type        = string
  default     = null
}

variable "subnets" {
  description = "Subnet ids where load balancer should be present"
  type        = list(string)
}

variable "stickiness_enabled" {
  description = "If true, enable stickiness on the target group ensuring a clients is forwarded to the same target."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources creatded by the module."
  type        = map(string)
  default     = {}
}

variable "target_group_port" {
  description = "TCP port that a target listens to to serve requests from the load balancer."
  type        = number
  default     = 80
}

variable "target_group_type" {
  description = "Target group type: instance, ip, alb. Default is instance."
  type        = string
  default     = "instance"
}

variable "upstream_module" {
  description = "Module that called this module."
  type        = string
  default     = null
}

variable "userdata" {
  description = "userdata for cloud-init to provision EC2 instances"
  type        = string
}

variable "vanta_owner" {
  description = "The email address of the instance's owner, and it should be set to the email address of a user in Vanta. An owner will not be assigned if there is no user in Vanta with the email specified."
  type        = string
  default     = null
}

variable "vanta_production_environments" {
  description = "Environment names to consider production grade in Vanta."
  type        = list(string)
  default = [
    "production",
    "prod"
  ]
}

variable "vanta_description" {
  description = "This tag allows administrators to set a description, for instance, or add any other descriptive information."
  type        = string
  default     = null
}

variable "vanta_contains_user_data" {
  description = "his tag allows administrators to define whether or not a resource contains user data (true) or if they do not contain user data (false)."
  type        = bool
  default     = false
}

variable "vanta_contains_ephi" {
  description = "This tag allows administrators to define whether or not a resource contains electronically Protected Health Information (ePHI). It can be set to either (true) or if they do not have ephi data (false)."
  type        = bool
  default     = false
}

variable "vanta_user_data_stored" {
  description = "This tag allows administrators to describe the type of user data the instance contains."
  type        = string
  default     = null
}

variable "vanta_no_alert" {
  description = "Administrators can add this tag to mark a resource as out of scope for their audit. If this tag is added, the administrator will need to set a reason for why it's not relevant to their audit."
  type        = string
  default     = null
}

variable "wait_for_capacity_timeout" {
  description = "How much time to wait until all instances are healthy"
  type        = string
  default     = "20m"
}

variable "zone_id" {
  description = "Domain name zone ID where the website will be available"
  type        = string
}

variable "certificate_issuers" {
  description = "List of certificate authority domains allowed to issue certificates for this domain (e.g., [\"amazon.com\", \"letsencrypt.org\"]). The module will format these as CAA records."
  type        = list(string)
  default     = ["amazon.com"]
}

variable "attach_tagret_group_to_asg" {
  description = <<-EOF
    ⚠️  DEPRECATED - Contains typo, use 'attach_target_group_to_asg' instead.
    This variable will be removed in v6.0.0. See deprecations.tf for details.
    Whether to register ASG instances in the target group. Disable if using ECS which registers targets itself.
  EOF
  type        = bool
  default     = null
}

variable "attach_target_group_to_asg" {
  description = "Whether to register ASG instances in the target group. Disable if using ECS which registers targets itself."
  type        = bool
  default     = true
}

variable "sns_topic_alarm_arn" {
  description = "ARN of SNS topic for Cloudwatch alarms on base EC2 instance."
  type        = string
  default     = null
}
