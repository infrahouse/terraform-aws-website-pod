output "asg_arn" {
  description = "ARN of the created autoscaling group"
  value       = aws_autoscaling_group.website.arn
}

output "asg_name" {
  description = "Name of the created autoscaling group"
  value       = aws_autoscaling_group.website.name
}

output "dns_name" {
  description = "DNS name of the load balancer."
  value       = aws_alb.website.dns_name
}

output "instance_profile_name" {
  description = "EC2 instance profile name."
  value       = module.instance_profile.instance_profile_name
}

output "load_balancer_arn" {
  description = "Load Balancer ARN"
  value       = aws_alb.website.arn
}

output "load_balancer_dns_name" {
  description = "Load balancer DNS name."
  value       = aws_alb.website.dns_name
}

output "target_group_arn" {
  description = "Target group ARN that listens to the service port."
  value       = aws_alb_target_group.website.arn
}

output "zone_id" {
  description = "Zone id where A records are created for the service."
  value       = aws_alb.website.zone_id
}

output "backend_security_group" {
  description = "Map with security group id and rules"
  value = {
    backend : {
      id : aws_security_group.backend.id
      rules : merge(

        {
          backend_ssh_local : aws_vpc_security_group_ingress_rule.backend_ssh_local.id
          backend_ssh_input : var.ssh_cidr_block != null ? aws_vpc_security_group_ingress_rule.backend_ssh_input[0].id : null
          backend_user_traffic : aws_vpc_security_group_ingress_rule.backend_user_traffic.id
          backend_icmp : aws_vpc_security_group_ingress_rule.backend_icmp.id
          backend_outgoing : aws_vpc_security_group_egress_rule.backend_outgoing.id
        },
        var.alb_healthcheck_port == var.target_group_port || var.alb_healthcheck_port == "traffic-port" ? {} : {
          backend_healthcheck : aws_vpc_security_group_ingress_rule.backend_healthcheck[0].id
        }
      )
    }
  }
}

output "instance_role_arn" {
  description = "ARN of the instance role."
  value       = module.instance_profile.instance_role_arn
}

output "instance_role_name" {
  description = "Name of the instance role."
  value       = module.instance_profile.instance_role_name
}

output "instance_role_policy_name" {
  description = "Policy name attached to EC2 instance profile."
  value       = module.instance_profile.instance_role_policy_name
}

output "instance_role_policy_arn" {
  description = "Policy ARN attached to EC2 instance profile."
  value       = module.instance_profile.instance_role_policy_arn
}

output "instance_role_policy_attachment" {
  description = "Policy attachment id."
  value       = module.instance_profile.instance_role_policy_attachment
}

output "ssl_listener_arn" {
  description = "SSL listener ARN"
  value       = aws_lb_listener.ssl.arn
}

output "load_balancer_security_groups" {
  description = "Security groups associated with the load balancer"
  value       = aws_alb.website.security_groups
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate used by the load balancer"
  value       = aws_acm_certificate.website.arn
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "backend_security_group_id" {
  description = "ID of the backend instances security group"
  value       = aws_security_group.backend.id
}

