# Monitoring Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (primary/secondary)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "alarm_email_endpoints" {
  description = "List of email addresses to receive alarm notifications"
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer"
  type        = string
  default     = ""
}

variable "target_group_arn_suffix" {
  description = "ARN suffix of the target group"
  type        = string
  default     = ""
}

variable "web_asg_name" {
  description = "Name of the web tier Auto Scaling Group"
  type        = string
  default     = ""
}

variable "app_asg_name" {
  description = "Name of the application tier Auto Scaling Group"
  type        = string
  default     = ""
}

variable "web_scale_up_policy_arn" {
  description = "ARN of the web tier scale up policy"
  type        = string
  default     = ""
}

variable "web_scale_down_policy_arn" {
  description = "ARN of the web tier scale down policy"
  type        = string
  default     = ""
}

variable "db_instance_id" {
  description = "ID of the RDS instance"
  type        = string
  default     = ""
}

variable "enable_ec2_alarms" {
  description = "Enable EC2 CloudWatch alarms"
  type        = bool
  default     = true
}

variable "enable_rds_alarms" {
  description = "Enable RDS CloudWatch alarms"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
