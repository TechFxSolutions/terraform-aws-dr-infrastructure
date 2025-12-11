# Global IAM Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "terraform-dr-infrastructure"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "terraform-dr-infrastructure"
    ManagedBy = "Terraform"
  }
}
