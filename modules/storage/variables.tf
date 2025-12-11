# Storage Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (primary/secondary)"
  type        = string
}

variable "enable_replication" {
  description = "Enable S3 cross-region replication"
  type        = bool
  default     = false
}

variable "replication_destination_bucket" {
  description = "ARN of the destination bucket for replication"
  type        = string
  default     = ""
}

variable "replication_kms_key_id" {
  description = "KMS key ID for replication destination encryption"
  type        = string
  default     = ""
}

variable "create_assets_bucket" {
  description = "Create S3 bucket for application assets"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
