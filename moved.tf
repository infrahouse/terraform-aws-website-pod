moved {
  from = aws_s3_bucket.access_log[0]
  to   = module.access_log.aws_s3_bucket.this
}

moved {
  from = aws_s3_bucket_public_access_block.public_access[0]
  to   = module.access_log.aws_s3_bucket_public_access_block.public_access
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.access_log[0]
  to   = module.access_log.aws_s3_bucket_server_side_encryption_configuration.default
}

moved {
  from = aws_s3_bucket_versioning.access_log[0]
  to   = module.access_log.aws_s3_bucket_versioning.enabled[0]
}

moved {
  from = aws_s3_bucket_policy.access_logs[0]
  to   = module.access_log.aws_s3_bucket_policy.this
}

moved {
  from = aws_vpc_security_group_ingress_rule.alb_listener_port
  to   = aws_vpc_security_group_ingress_rule.alb_listener_port["0.0.0.0/0"]
}

moved {
  from = aws_vpc_security_group_ingress_rule.https
  to   = aws_vpc_security_group_ingress_rule.https["0.0.0.0/0"]
}

# aws_autoscaling_policy.cpu_load gained a count when autoscaling_target_cpu_load
# became nullable (null = don't create the policy). Preserve state for existing
# consumers who keep a non-null target so the policy is not destroyed/recreated.
moved {
  from = aws_autoscaling_policy.cpu_load
  to   = aws_autoscaling_policy.cpu_load[0]
}
