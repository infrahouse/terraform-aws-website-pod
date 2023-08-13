variable "ami" {
  description = "Image for EC2 instances"
  type        = string
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

variable "dns_zone" {
  description = "Domain name zone where the website will be available"
  type        = string
}

# Extra "A" records in dns_zone
# If the zone is infrahouse.com and the extra "A" records ["www"], then the module
# will create records (and a certificate for):
# - infrahouse.com - as it's the var.dns_zone
# - www.infrahouse.com
# If we pass A records as ["something"] then the module
# will create the "A" record something.infrahouse.com
variable "dns_a_records_extra" {
  description = "List of extra A records in the dns_zone that will resolve to ALB dns name."
  type        = list(string)
  default     = ["www"]
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

variable "instance_type" {
  description = "EC2 instances type"
  type        = string
  default     = "t3.micro"
}

variable "internet_gateway_id" {
  description = "AWS Internet Gateway must be present. Ensure by passing its id."
  type        = string
}

variable "health_check_type" {
  # Good summary
  # https://stackoverflow.com/questions/42466157/whats-the-difference-between-elb-health-check-and-ec2-health-check
  description = "Type of healthcheck the ASG uses. Can be EC2 or ELB."
  type        = string
  default     = "ELB"
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

variable "subnets" {
  description = "Subnet ids where load balancer should be present"
  type        = list(string)
}

variable "backend_subnets" {
  description = "Subnet ids where EC2 instances should be present"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to each resource"
  default     = {}
}

variable "userdata" {
  description = "userdata for cloud-init to provision EC2 instances"
}

variable "key_pair_name" {
  description = "SSH keypair name to be deployed in EC2 instances"
}

variable "alb_healthcheck_path" {
  description = "Path on the webserver that the elb will check to determine whether the instance is healthy or not"
  default     = "/index.html"
}

variable "alb_healthcheck_port" {
  description = "Port of the webserver that the elb will check to determine whether the instance is healthy or not"
  default     = "80"
}

variable "alb_healthcheck_protocol" {
  description = "Protocol to use with the webserver that the elb will check to determine whether the instance is healthy or not"
  default     = "HTTP"
}

variable "alb_healthcheck_healthy_threshold" {
  description = "Number of times the host have to pass the test to be considered healthy"
  default     = 2
}

variable "alb_healthcheck_uhealthy_threshold" {
  description = "Number of times the host have to pass the test to be considered UNhealthy"
  default     = 2
}

variable "alb_healthcheck_interval" {
  description = "Number of seconds between checks"
  default     = 5
}

variable "alb_healthcheck_timeout" {
  description = "Number of seconds to timeout a check"
  default     = 4
}

variable "alb_healthcheck_response_code_matcher" {
  description = "Range of http return codes that can match"
  default     = "200-299"
}

variable "autoscaling_target_cpu_load" {
  description = "Target CPU load for autoscaling"
  default     = 60
  type        = number
}

variable "health_check_grace_period" {
  description = "ASG will wait up to this number of seconds for instance to become healthy"
  default     = 300
}

variable "wait_for_capacity_timeout" {
  description = "How much time to wait until all instances are healthy"
  type        = string
  default     = "20m"
}

variable "max_instance_lifetime_days" {
  description = "The maximum amount of time, in _days_, that an instance can be in service, values must be either equal to 0 or between 7 and 365 days."
  type        = number
  default     = 30
}

variable "webserver_permissions" {
    description = "A JSON with a permissions policy document. The policy will be attached to the webserver instance profile."
    type = string
}
