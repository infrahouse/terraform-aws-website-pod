module "access_log" {
  source  = "registry.infrahouse.com/infrahouse/s3-bucket/aws"
  version = "0.6.0"

  bucket_prefix      = "${var.alb_name_prefix}-access-log-"
  bucket_policy      = data.aws_iam_policy_document.access_logs.json
  force_destroy      = var.alb_access_log_force_destroy
  replication_region = var.replication_region

  tags = merge(
    local.default_module_tags,
    {
      VantaContainsUserData = false
      VantaContainsEPHI     = false
    }
  )
}

resource "aws_s3_bucket_lifecycle_configuration" "access_log" {
  bucket = module.access_log.bucket_name

  rule {
    id     = "expire-access-logs"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    expiration {
      days = var.alb_access_log_expiration_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.alb_access_log_expiration_days
    }
  }
}

data "aws_iam_policy_document" "access_logs" {
  statement {
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${local.elb_account_map[local.region]}:root"
      ]
    }
    actions = [
      "s3:PutObject",
    ]
    resources = [
      "${module.access_log.bucket_arn}/*"
    ]
  }
}
