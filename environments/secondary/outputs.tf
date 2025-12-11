# Secondary Environment Outputs (Disaster Recovery)

# Network Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.networking.public_subnet_ids
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
output "db_replica_endpoint" {
  description = "Connection endpoint for the RDS read replica"
  value       = module.database.replica_instance_endpoint
}

output "db_instance_id" {
  description = "ID of the RDS instance"
  value       = module.database.replica_instance_id != null ? module.database.replica_instance_id : module.database.db_instance_id
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

# Application URL (Standby)
output "application_url" {
  description = "URL to access the application (standby)"
  value       = "http://${module.compute.alb_dns_name}"
}

# Failover Instructions
output "failover_instructions" {
  description = "Instructions for failover to secondary region"
  value = <<-EOT
    DISASTER RECOVERY - SECONDARY REGION (STANDBY)
    
    Application URL (Standby): http://${module.compute.alb_dns_name}
    
    Current Status: STANDBY MODE
    - Minimal EC2 capacity (can be scaled up)
    - Read replica database (can be promoted)
    
    FAILOVER PROCEDURE:
    
    1. Scale up Auto Scaling Groups:
       aws autoscaling set-desired-capacity --auto-scaling-group-name ${module.compute.web_asg_name} --desired-capacity 2 --region ${var.aws_region}
       aws autoscaling set-desired-capacity --auto-scaling-group-name ${module.compute.app_asg_name} --desired-capacity 2 --region ${var.aws_region}
    
    2. Promote Read Replica to Master:
       aws rds promote-read-replica --db-instance-identifier ${module.database.replica_instance_id != null ? module.database.replica_instance_id : "REPLICA_ID"} --region ${var.aws_region}
    
    3. Update DNS to point to: ${module.compute.alb_dns_name}
    
    4. Verify application is operational
    
    For detailed failover procedures, see: docs/RUNBOOK.md
  EOT
}
