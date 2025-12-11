# S3 Backend Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "terraform-dr-infrastructure"
}

variable "aws_region" {
  description = "AWS region for the S3 bucket and DynamoDB table"
  type        = string
  default     = "us-east-1"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "terraform-dr-infrastructure"
    ManagedBy = "Terraform"
  }
}
