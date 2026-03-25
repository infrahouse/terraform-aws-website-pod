resource "random_string" "glue_suffix" {
  count   = local.glue_enabled ? 1 : 0
  length  = 6
  special = false
  upper   = false
}

module "athena_results" {
  count   = local.glue_enabled ? 1 : 0
  source  = "registry.infrahouse.com/infrahouse/s3-bucket/aws"
  version = "0.3.1"

  bucket_prefix = "${var.alb_name_prefix}-athena-results-"
  force_destroy = var.alb_access_log_force_destroy

  tags = local.default_module_tags
}

resource "aws_s3_bucket_lifecycle_configuration" "athena_results" {
  count  = local.glue_enabled ? 1 : 0
  bucket = module.athena_results[0].bucket_name

  rule {
    id     = "expire-query-results"
    status = "Enabled"

    expiration {
      days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_athena_workgroup" "alb_access_logs" {
  count         = local.glue_enabled ? 1 : 0
  name          = "${var.service_name}-alb-logs-${local.glue_suffix}"
  description   = "Athena workgroup for querying ALB access logs for ${var.service_name}"
  force_destroy = var.alb_access_log_force_destroy

  configuration {
    result_configuration {
      output_location = "s3://${module.athena_results[0].bucket_name}/results/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }

  tags = local.default_module_tags
}

resource "aws_glue_catalog_database" "alb_access_logs" {
  count       = local.glue_enabled ? 1 : 0
  name        = local.glue_database
  description = "ALB access logs for ${var.service_name}"
  tags        = local.default_module_tags
}

resource "aws_glue_catalog_table" "alb_access_logs" {
  count         = local.glue_enabled ? 1 : 0
  name          = local.glue_table
  database_name = aws_glue_catalog_database.alb_access_logs[0].name
  description   = "ALB access logs for ${var.service_name}"

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "EXTERNAL"           = "TRUE"
    "has_encrypted_data" = "true"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.access_log[0].id}/AWSLogs/${local.account_id}/elasticloadbalancing/${local.region}/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.RegexSerDe"
      parameters = {
        "serialization.format" = "1"
        "input.regex" = join(" ", [
          "([^ ]*)",                     # type
          "([^ ]*)",                     # time
          "([^ ]*)",                     # elb
          "([^ ]*):([0-9]*)",            # client_ip : client_port
          "([^ ]*)[:-]([0-9]*)",         # target_ip : target_port
          "([-.0-9]*)",                  # request_processing_time
          "([-.0-9]*)",                  # target_processing_time
          "([-.0-9]*)",                  # response_processing_time
          "(|[-0-9]*)",                  # elb_status_code
          "(-|[-0-9]*)",                 # target_status_code
          "([-0-9]*)",                   # received_bytes
          "([-0-9]*)",                   # sent_bytes
          "\"([^ ]*) (.*) (- |[^ ]*)\"", # request_verb request_url request_proto
          "\"([^\"]*)\"",                # user_agent
          "([A-Z0-9-_]+)",               # ssl_cipher
          "([A-Za-z0-9.-]*)",            # ssl_protocol
          "([^ ]*)",                     # target_group_arn
          "\"([^\"]*)\"",                # trace_id
          "\"([^\"]*)\"",                # domain_name
          "\"([^\"]*)\"",                # chosen_cert_arn
          "([-.0-9]*)",                  # matched_rule_priority
          "([^ ]*)",                     # request_creation_time
          "\"([^\"]*)\"",                # actions_executed
          "\"([^\"]*)\"",                # redirect_url
          "\"([^ ]*)\"",                 # lambda_error_reason
          "\"([^\\s]+?)\"",              # target_port_list
          "\"([^\\s]+)\"",               # target_status_code_list
          "\"([^ ]*)\"",                 # classification
          "\"([^ ]*)\"",                 # classification_reason
          "?([^ ]*)?.*",                 # conn_trace_id + future fields
        ])
      }
    }

    columns {
      name = "type"
      type = "string"
    }
    columns {
      name = "time"
      type = "string"
    }
    columns {
      name = "elb"
      type = "string"
    }
    columns {
      name = "client_ip"
      type = "string"
    }
    columns {
      name = "client_port"
      type = "int"
    }
    columns {
      name = "target_ip"
      type = "string"
    }
    columns {
      name = "target_port"
      type = "int"
    }
    columns {
      name = "request_processing_time"
      type = "double"
    }
    columns {
      name = "target_processing_time"
      type = "double"
    }
    columns {
      name = "response_processing_time"
      type = "double"
    }
    columns {
      name = "elb_status_code"
      type = "int"
    }
    columns {
      name = "target_status_code"
      type = "string"
    }
    columns {
      name = "received_bytes"
      type = "bigint"
    }
    columns {
      name = "sent_bytes"
      type = "bigint"
    }
    columns {
      name = "request_verb"
      type = "string"
    }
    columns {
      name = "request_url"
      type = "string"
    }
    columns {
      name = "request_proto"
      type = "string"
    }
    columns {
      name = "user_agent"
      type = "string"
    }
    columns {
      name = "ssl_cipher"
      type = "string"
    }
    columns {
      name = "ssl_protocol"
      type = "string"
    }
    columns {
      name = "target_group_arn"
      type = "string"
    }
    columns {
      name = "trace_id"
      type = "string"
    }
    columns {
      name = "domain_name"
      type = "string"
    }
    columns {
      name = "chosen_cert_arn"
      type = "string"
    }
    columns {
      name = "matched_rule_priority"
      type = "string"
    }
    columns {
      name = "request_creation_time"
      type = "string"
    }
    columns {
      name = "actions_executed"
      type = "string"
    }
    columns {
      name = "redirect_url"
      type = "string"
    }
    columns {
      name = "lambda_error_reason"
      type = "string"
    }
    columns {
      name = "target_port_list"
      type = "string"
    }
    columns {
      name = "target_status_code_list"
      type = "string"
    }
    columns {
      name = "classification"
      type = "string"
    }
    columns {
      name = "classification_reason"
      type = "string"
    }
    columns {
      name = "conn_trace_id"
      type = "string"
    }
  }
}
