# In-house monitoring only (CloudWatch + SNS). Free tier covers 10 alarms, 10 custom metrics,
# 3 dashboards and 5 GB of logs, so this module stays at 9 alarms and 7-day log retention.

resource "aws_sns_topic" "alerts" {
  name = "${var.name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email # confirm the subscription from the email AWS sends
}

# Log groups are created here (not by the agent) so retention is limited and costs stay in the free tier.
resource "aws_cloudwatch_log_group" "app" {
  for_each          = toset(["ui", "api"])
  name              = "/movie-analyst/${var.env}/${each.key}"
  retention_in_days = 7
}

locals {
  alarms = {
    ui-cpu = {
      namespace = "AWS/EC2", metric = "CPUUtilization", stat = "Average", op = "GreaterThanThreshold"
      threshold = 80, period = 300, evals = 2
      dims      = { InstanceId = var.ui_instance_id }
      desc      = "Front-end CPU above 80% for 10 minutes"
    }
    api-cpu = {
      namespace = "AWS/EC2", metric = "CPUUtilization", stat = "Average", op = "GreaterThanThreshold"
      threshold = 80, period = 300, evals = 2
      dims      = { InstanceId = var.api_instance_id }
      desc      = "Back-end CPU above 80% for 10 minutes"
    }
    ui-status-check = {
      namespace = "AWS/EC2", metric = "StatusCheckFailed", stat = "Maximum", op = "GreaterThanThreshold"
      threshold = 0, period = 60, evals = 2
      dims      = { InstanceId = var.ui_instance_id }
      desc      = "Front-end instance failed an EC2 status check"
    }
    api-status-check = {
      namespace = "AWS/EC2", metric = "StatusCheckFailed", stat = "Maximum", op = "GreaterThanThreshold"
      threshold = 0, period = 60, evals = 2
      dims      = { InstanceId = var.api_instance_id }
      desc      = "Back-end instance failed an EC2 status check"
    }
    public-alb-unhealthy = {
      namespace = "AWS/ApplicationELB", metric = "UnHealthyHostCount", stat = "Maximum", op = "GreaterThanThreshold"
      threshold = 0, period = 60, evals = 2
      dims      = { LoadBalancer = var.public_lb_suffix, TargetGroup = var.public_tg_suffix }
      desc      = "Public ALB has an unhealthy front-end target"
    }
    internal-alb-unhealthy = {
      namespace = "AWS/ApplicationELB", metric = "UnHealthyHostCount", stat = "Maximum", op = "GreaterThanThreshold"
      threshold = 0, period = 60, evals = 2
      dims      = { LoadBalancer = var.internal_lb_suffix, TargetGroup = var.internal_tg_suffix }
      desc      = "Internal ALB has an unhealthy back-end target"
    }
    public-alb-5xx = {
      namespace = "AWS/ApplicationELB", metric = "HTTPCode_Target_5XX_Count", stat = "Sum", op = "GreaterThanThreshold"
      threshold = 5, period = 300, evals = 1
      dims      = { LoadBalancer = var.public_lb_suffix }
      desc      = "More than 5 HTTP 5xx responses from the front-end in 5 minutes"
    }
    rds-cpu = {
      namespace = "AWS/RDS", metric = "CPUUtilization", stat = "Average", op = "GreaterThanThreshold"
      threshold = 80, period = 300, evals = 2
      dims      = { DBInstanceIdentifier = var.rds_identifier }
      desc      = "RDS CPU above 80% for 10 minutes"
    }
    rds-free-storage = {
      namespace = "AWS/RDS", metric = "FreeStorageSpace", stat = "Minimum", op = "LessThanThreshold"
      threshold = 2147483648, period = 300, evals = 1
      dims      = { DBInstanceIdentifier = var.rds_identifier }
      desc      = "RDS free storage below 2 GB"
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = local.alarms

  alarm_name          = "${var.name}-${each.key}"
  alarm_description   = each.value.desc
  namespace           = each.value.namespace
  metric_name         = each.value.metric
  statistic           = each.value.stat
  comparison_operator = each.value.op
  threshold           = each.value.threshold
  period              = each.value.period
  evaluation_periods  = each.value.evals
  dimensions          = each.value.dims
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = var.name

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title  = "CPU utilization (%)"
          region = var.region
          view   = "timeSeries"
          stat   = "Average"
          period = 300
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", var.ui_instance_id, { label = "UI" }],
            ["AWS/EC2", "CPUUtilization", "InstanceId", var.api_instance_id, { label = "API" }],
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_identifier, { label = "RDS" }]
          ]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title  = "Memory used (%) - CloudWatch agent"
          region = var.region
          view   = "timeSeries"
          stat   = "Average"
          period = 300
          metrics = [
            ["CWAgent", "mem_used_percent", "InstanceId", var.ui_instance_id, { label = "UI" }],
            ["CWAgent", "mem_used_percent", "InstanceId", var.api_instance_id, { label = "API" }]
          ]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title  = "Public ALB requests and 5xx"
          region = var.region
          view   = "timeSeries"
          stat   = "Sum"
          period = 300
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.public_lb_suffix, { label = "Requests" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.public_lb_suffix, { label = "5xx" }]
          ]
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title  = "Healthy targets"
          region = var.region
          view   = "timeSeries"
          stat   = "Minimum"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", var.public_lb_suffix, "TargetGroup", var.public_tg_suffix, { label = "UI" }],
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", var.internal_lb_suffix, "TargetGroup", var.internal_tg_suffix, { label = "API" }]
          ]
        }
      },
      {
        type = "metric", x = 0, y = 12, width = 12, height = 6
        properties = {
          title  = "RDS connections"
          region = var.region
          view   = "timeSeries"
          stat   = "Average"
          period = 300
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.rds_identifier]
          ]
        }
      },
      {
        type = "metric", x = 12, y = 12, width = 12, height = 6
        properties = {
          title  = "RDS free storage (bytes)"
          region = var.region
          view   = "timeSeries"
          stat   = "Minimum"
          period = 300
          metrics = [
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", var.rds_identifier]
          ]
        }
      }
    ]
  })
}
