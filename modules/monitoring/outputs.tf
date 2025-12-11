# Monitoring Module Outputs

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alarms"
  value       = aws_sns_topic.alarms.arn
}

output "flow_logs_log_group_name" {
  description = "Name of the CloudWatch log group for VPC flow logs"
  value       = aws_cloudwatch_log_group.flow_logs.name
}

output "flow_logs_log_group_arn" {
  description = "ARN of the CloudWatch log group for VPC flow logs"
  value       = aws_cloudwatch_log_group.flow_logs.arn
}

output "flow_logs_role_arn" {
  description = "ARN of the IAM role for VPC flow logs"
  value       = aws_iam_role.flow_logs.arn
}

output "cloudwatch_kms_key_id" {
  description = "ID of the KMS key for CloudWatch Logs encryption"
  value       = aws_kms_key.cloudwatch.id
}

output "cloudwatch_kms_key_arn" {
  description = "ARN of the KMS key for CloudWatch Logs encryption"
  value       = aws_kms_key.cloudwatch.arn
}

output "sns_kms_key_id" {
  description = "ID of the KMS key for SNS encryption"
  value       = aws_kms_key.sns.id
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}
