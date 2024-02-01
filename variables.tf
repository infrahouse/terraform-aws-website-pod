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
  description = "Number of times the host have to pass the test to be considered UNhealthy"
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

variable "ami" {
  description = "Image for EC2 instances"
  type        = string
}

variable "min_healthy_percentage" {
  description = "Amount of capacity in the Auto Scaling group that must remain healthy during an instance refresh to allow the operation to continue, as a percentage of the desired capacity of the Auto Scaling group."
  type        = number
  default     = 100
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

variable "attach_tagret_group_to_asg" {
  description = "By default we want to register all ASG instances in the target group. However ECS registers targets itself. Disable it if using website-pod for ECS."
  type        = bool
  default     = true
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

variable "instance_profile" {
  description = "IAM profile name to be created for the webserver instances."
  type        = string
  default     = "webserver"
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
  default     = 300
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
}
variable "service_name" {
  description = "Descriptive name of a service that will use this VPC"
  type        = string
  default     = "website"
}

variable "ssh_cidr_block" {
  description = "CIDR range that is allowed to SSH into the backend instances"
  type        = string
  default     = "0.0.0.0/0"
}

variable "subnets" {
  description = "Subnet ids where load balancer should be present"
  type        = list(string)
}

variable "stickiness_enabled" {
  description = "If true, enable stickiness on the target group ensuring a clients is forwarded to the same target."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to instances in the autoscaling group."
  type        = map(string)
  default = {
    Name : "webserver"
  }
}

variable "target_group_port" {
  description = "TCP port that a target listens to to serve requests from the load balancer."
  type        = number
  default     = 80
}

variable "userdata" {
  description = "userdata for cloud-init to provision EC2 instances"
  type        = string
}

variable "wait_for_capacity_timeout" {
  description = "How much time to wait until all instances are healthy"
  type        = string
  default     = "20m"
}

variable "webserver_permissions" {
  description = "A JSON with a permissions policy document. The policy will be attached to the webserver instance profile."
  type        = string
}

variable "zone_id" {
  description = "Domain name zone ID where the website will be available"
  type        = string
}
