locals {
  module = "infrahouse/website-pod/aws"
  # Module version is applied as a tag to the ALB (the primary resource)
  # per InfraHouse standards for tracking module versions in deployed infrastructure
  module_version = "5.12.1"
  default_module_tags = merge(
    {
      environment : var.environment
      service : var.service_name
      account : data.aws_caller_identity.current.account_id
      created_by_module : local.module
    },
    var.upstream_module != null ? {
      upstream_module : var.upstream_module
    } : {},
    local.vanta_tags,
    var.tags
  )

  default_asg_tags = merge(
    {
      Name : var.service_name
    },
    local.default_module_tags,
    data.aws_default_tags.provider.tags,
  )

  vanta_tags = merge(
    var.vanta_owner != null ? {
      VantaOwner : var.vanta_owner
    } : {},
    {
      VantaNonProd : !contains(var.vanta_production_environments, var.environment)
      VantaContainsUserData : var.vanta_contains_user_data
      VantaContainsEPHI : var.vanta_contains_ephi
    },
    var.vanta_description != null ? {
      VantaDescription : var.vanta_description
    } : {},
    var.vanta_user_data_stored != null ? {
      VantaUserDataStored : var.vanta_user_data_stored
    } : {},
    var.vanta_no_alert != null ? {
      VantaNoAlert : var.vanta_no_alert
    } : {}
  )

  min_elb_capacity = var.asg_min_elb_capacity != null ? var.asg_min_elb_capacity : var.asg_min_size
  # See https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html
  elb_account_map = {
    "us-east-1"      = "127311923021"
    "us-east-2"      = "033677994240"
    "us-west-1"      = "027434742980"
    "us-west-2"      = "797873946194"
    "ca-central-1"   = "985666609251"
    "eu-central-1"   = "054676820928"
    "eu-west-1"      = "156460612806"
    "eu-west-2"      = "652711504416"
    "eu-west-3"      = "009996457667"
    "eu-north-1"     = "897822967062"
    "ap-east-1"      = "754344448648"
    "ap-northeast-1" = "582318560864"
    "ap-northeast-2" = "600734575887"
    "ap-northeast-3" = "383597477331"
    "ap-southeast-1" = "114774131450"
    "ap-southeast-2" = "783225319266"
    "ap-southeast-3" = "589379963580"
    "ap-southeast-4" = "297686090294"
    "ap-south-1"     = "718504428378"
    "ap-south-2"     = "635631232127"
    "sa-east-1"      = "507241528517"
    "me-south-1"     = "076674570225"
    "me-central-1"   = "741774495389"
    "af-south-1"     = "098369216593"
    "eu-south-1"     = "635631232127"
    "eu-south-2"     = "732548202433"
    "eu-central-2"   = "503297430113"
    "il-central-1"   = "581348220920"
  }

  # Backward compatibility for deprecated variables with typos
  # Priority: new variable > old variable > default (the default is already set on the new variable)
  unhealthy_threshold = coalesce(
    var.alb_healthcheck_unhealthy_threshold,
    var.alb_healthcheck_uhealthy_threshold,
  )

  attach_tg_to_asg = coalesce(
    var.attach_target_group_to_asg,
    var.attach_tagret_group_to_asg,
  )

  # Vanta Compliance: CloudWatch Alarms
  # Determine if alarms should be created
  alarms_enabled = length(var.alarm_emails) > 0 || length(var.alarm_topic_arns) > 0

  # Calculate response time threshold: default to 80% of idle timeout
  alarm_target_response_time = coalesce(
    var.alarm_target_response_time_threshold,
    var.alb_idle_timeout * 0.8
  )

  # Calculate CPU threshold: default to autoscaling target + 30%
  # Cap at 99% instead of 100% because the alarm uses GreaterThanThreshold (>).
  # A threshold of 100 would mean "alert when CPU > 100%" which is impossible.
  alarm_cpu_threshold = min(
    coalesce(
      var.alarm_cpu_utilization_threshold,
      var.autoscaling_target_cpu_load + 30
    ),
    99
  )

  # SNS topic ARNs to send alarms to
  alarm_sns_topics = concat(
    length(var.alarm_emails) > 0 ? [aws_sns_topic.alarms[0].arn] : [],
    var.alarm_topic_arns
  )
}
