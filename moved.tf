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
