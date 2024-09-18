resource "aws_s3_bucket" "access_log" {
  count         = var.alb_access_log_enabled ? 1 : 0
  bucket_prefix = "${var.alb_name_prefix}-access-log-"
  force_destroy = var.alb_access_log_force_destroy
  tags          = local.default_module_tags
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
