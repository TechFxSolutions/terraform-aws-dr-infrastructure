# Primary Environment Outputs

# Network Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.networking.public_subnet_ids
}

output "private_web_subnet_ids" {
  description = "IDs of private web tier subnets"
  value       = module.networking.private_web_subnet_ids
}

output "private_app_subnet_ids" {
  description = "IDs of private application tier subnets"
  value       = module.networking.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  description = "IDs of private database tier subnets"
  value       = module.networking.private_db_subnet_ids
}

# Load Balancer Outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.compute.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.compute.alb_zone_id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.compute.alb_arn
}

# Compute Outputs
output "web_asg_name" {
  description = "Name of the web tier Auto Scaling Group"
  value       = module.compute.web_asg_name
}

output "app_asg_name" {
  description = "Name of the application tier Auto Scaling Group"
  value       = module.compute.app_asg_name
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = module.compute.bastion_public_ip
}

# Database Outputs
output "db_instance_endpoint" {
  description = "Connection endpoint for the RDS instance"
  value       = module.database.db_instance_endpoint
}

output "db_instance_id" {
  description = "ID of the RDS instance"
  value       = module.database.db_instance_id
}

output "db_secret_arn" {
  description = "ARN of the database credentials secret"
  value       = module.database.db_secret_arn
}

# Storage Outputs
output "logs_bucket_name" {
  description = "Name of the logs S3 bucket"
  value       = module.storage.logs_bucket_id
}

output "backups_bucket_name" {
  description = "Name of the backups S3 bucket"
  value       = module.storage.backups_bucket_id
}

# Monitoring Outputs
output "sns_topic_arn" {
  description = "ARN of the SNS topic for alarms"
  value       = module.monitoring.sns_topic_arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = module.monitoring.dashboard_name
}

# Application URL
output "application_url" {
  description = "URL to access the application"
  value       = "http://${module.compute.alb_dns_name}"
}

# Connection Instructions
output "connection_instructions" {
  description = "Instructions for connecting to the infrastructure"
  value = <<-EOT
    Application URL: http://${module.compute.alb_dns_name}
    
    Bastion Host: ${module.compute.bastion_public_ip != null ? module.compute.bastion_public_ip : "Not enabled"}
    
    Database Endpoint: ${module.database.db_instance_endpoint}
    Database Credentials: Stored in AWS Secrets Manager
    Secret ARN: ${module.database.db_secret_arn}
    
    To retrieve database password:
    aws secretsmanager get-secret-value --secret-id ${module.database.db_secret_arn} --query SecretString --output text | jq -r .password
    
    To connect via bastion:
    ssh -i your-key.pem ec2-user@${module.compute.bastion_public_ip != null ? module.compute.bastion_public_ip : "BASTION_IP"}
  EOT
}
