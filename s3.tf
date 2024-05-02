resource "aws_s3_bucket" "access_log" {
  count         = var.alb_access_log_enabled ? 1 : 0
  bucket_prefix = "${var.alb_name_prefix}-access-log-"
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  count                   = var.alb_access_log_enabled ? 1 : 0
  bucket                  = aws_s3_bucket.access_log[count.index].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_s3_bucket_policy" "access_logs" {
  count  = var.alb_access_log_enabled ? 1 : 0
  bucket = aws_s3_bucket.access_log[count.index].id
  policy = data.aws_iam_policy_document.access_logs[count.index].json
}


data "aws_iam_policy_document" "access_logs" {
  count = var.alb_access_log_enabled ? 1 : 0
  statement {
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${local.elb_account_map[data.aws_region.current.name]}:root"
      ]
    }
    actions = [
      "s3:PutObject",
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.access_log[count.index].id}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]
  }
}

locals {

  # See https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html
  elb_account_map = {
    "us-east-1" : "127311923021"
    "us-east-2" : "033677994240"
    "us-west-1" : "027434742980"
    "us-west-2" : "797873946194"

  }
}
