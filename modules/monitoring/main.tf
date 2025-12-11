# Monitoring Module - CloudWatch Alarms, Dashboards, and SNS

# SNS Topic for Alarms
resource "aws_sns_topic" "alarms" {
  name              = "${var.project_name}-${var.environment}-alarms"
  display_name      = "Infrastructure Alarms - ${var.environment}"
  kms_master_key_id = aws_kms_key.sns.id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-alarms-topic"
    }
  )
}

# SNS Topic Subscription
resource "aws_sns_topic_subscription" "alarms_email" {
  count     = length(var.alarm_email_endpoints)
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email_endpoints[count.index]
}

# KMS Key for SNS Encryption
resource "aws_kms_key" "sns" {
  description             = "KMS key for SNS encryption in ${var.environment} environment"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-sns-kms"
    }
  )
}

resource "aws_kms_alias" "sns" {
  name          = "alias/${var.project_name}-${var.environment}-sns"
  target_key_id = aws_kms_key.sns.key_id
}

# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/${var.project_name}-${var.environment}-flow-logs"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.cloudwatch.arn

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-flow-logs"
    }
  )
}

# KMS Key for CloudWatch Logs
resource "aws_kms_key" "cloudwatch" {
  description             = "KMS key for CloudWatch Logs encryption in ${var.environment} environment"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-cloudwatch-kms"
    }
  )
}

resource "aws_kms_alias" "cloudwatch" {
  name          = "alias/${var.project_name}-${var.environment}-cloudwatch"
  target_key_id = aws_kms_key.cloudwatch.key_id
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# ALB CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "This metric monitors ALB target response time"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors unhealthy hosts behind ALB"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors 5xx errors from targets"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = var.common_tags
}

# EC2 CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "ec2_cpu_high" {
  count               = var.enable_ec2_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-ec2-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors EC2 CPU utilization"
  alarm_actions       = [aws_sns_topic.alarms.arn, var.web_scale_up_policy_arn]

  dimensions = {
    AutoScalingGroupName = var.web_asg_name
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "ec2_cpu_low" {
  count               = var.enable_ec2_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-ec2-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "20"
  alarm_description   = "This metric monitors EC2 CPU utilization for scale down"
  alarm_actions       = [var.web_scale_down_policy_arn]

  dimensions = {
    AutoScalingGroupName = var.web_asg_name
  }

  tags = var.common_tags
}

# RDS CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  count               = var.enable_rds_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors RDS CPU utilization"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  count               = var.enable_rds_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-rds-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "2000000000" # 2GB in bytes
  alarm_description   = "This metric monitors RDS free storage space"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  count               = var.enable_rds_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-rds-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors RDS database connections"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }

  tags = var.common_tags
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", { stat = "Average", label = "Response Time" }],
            [".", "RequestCount", { stat = "Sum", label = "Request Count" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ALB Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", { stat = "Average", label = "CPU Utilization" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "EC2 CPU Utilization"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", { stat = "Average", label = "CPU" }],
            [".", "DatabaseConnections", { stat = "Average", label = "Connections" }],
            [".", "FreeStorageSpace", { stat = "Average", label = "Free Storage" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS Metrics"
        }
      }
    ]
  })
}

# IAM Role for VPC Flow Logs
resource "aws_iam_role" "flow_logs" {
  name_prefix = "${var.project_name}-${var.environment}-flow-logs-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-flow-logs-role"
    }
  )
}

resource "aws_iam_role_policy" "flow_logs" {
  name_prefix = "${var.project_name}-${var.environment}-flow-logs-"
  role        = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}
