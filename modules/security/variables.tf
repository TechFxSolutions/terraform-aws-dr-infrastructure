# Security Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (primary/secondary)"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of public subnets"
  type        = list(string)
}

variable "private_web_subnet_ids" {
  description = "IDs of private web tier subnets"
  type        = list(string)
}

variable "private_app_subnet_ids" {
  description = "IDs of private application tier subnets"
  type        = list(string)
}

variable "private_db_subnet_ids" {
  description = "IDs of private database tier subnets"
  type        = list(string)
}

variable "app_port" {
  description = "Application port number"
  type        = number
  default     = 8080
}

variable "bastion_allowed_cidrs" {
  description = "CIDR blocks allowed to access bastion host"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
