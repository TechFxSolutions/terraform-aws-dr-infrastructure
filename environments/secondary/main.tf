# Secondary Region Infrastructure Configuration (Disaster Recovery)

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Backend configuration - uncomment after creating S3 backend
  # backend "s3" {
  #   # Configure with: terraform init -backend-config=backend.hcl
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Local variables
locals {
  environment = "secondary"
  common_tags = {
    Project     = var.project_name
    Environment = local.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Networking Module
module "networking" {
  source = "../../modules/networking"

  project_name       = var.project_name
  environment        = local.environment
  aws_region         = var.aws_region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  enable_nat_gateway            = var.enable_nat_gateway
  enable_flow_logs              = var.enable_flow_logs
  flow_logs_role_arn            = module.monitoring.flow_logs_role_arn
  flow_logs_destination_arn     = module.monitoring.flow_logs_log_group_arn
  flow_logs_destination_type    = "cloud-watch-logs"
  enable_vpc_endpoints          = var.enable_vpc_endpoints

  common_tags = local.common_tags
}

# Security Module
module "security" {
  source = "../../modules/security"

  project_name             = var.project_name
  environment              = local.environment
  vpc_id                   = module.networking.vpc_id
  vpc_cidr                 = module.networking.vpc_cidr
  public_subnet_ids        = module.networking.public_subnet_ids
  private_web_subnet_ids   = module.networking.private_web_subnet_ids
  private_app_subnet_ids   = module.networking.private_app_subnet_ids
  private_db_subnet_ids    = module.networking.private_db_subnet_ids
  app_port                 = var.app_port
  bastion_allowed_cidrs    = var.bastion_allowed_cidrs

  common_tags = local.common_tags
}

# Storage Module
module "storage" {
  source = "../../modules/storage"

  project_name                   = var.project_name
  environment                    = local.environment
  enable_replication             = var.enable_replication
  replication_destination_bucket = var.replication_destination_bucket
  replication_kms_key_id         = var.replication_kms_key_id
  create_assets_bucket           = var.create_assets_bucket

  common_tags = local.common_tags
}

# Database Module - Read Replica
module "database" {
  source = "../../modules/database"

  project_name                = var.project_name
  environment                 = local.environment
  is_primary                  = false  # This is the secondary region
  private_db_subnet_ids       = module.networking.private_db_subnet_ids
  database_security_group_id  = module.security.database_security_group_id

  db_engine                   = var.db_engine
  db_engine_version           = var.db_engine_version
  db_instance_class           = var.db_instance_class
  db_allocated_storage        = var.db_allocated_storage
  db_max_allocated_storage    = var.db_max_allocated_storage
  db_name                     = var.db_name
  db_username                 = var.db_username
  db_parameter_group_family   = var.db_parameter_group_family

  # Read replica configuration
  source_db_identifier        = var.source_db_identifier

  enable_multi_az             = false  # Read replicas don't support Multi-AZ
  backup_retention_period     = var.backup_retention_period
  skip_final_snapshot         = var.skip_final_snapshot

  enable_enhanced_monitoring  = var.enable_enhanced_monitoring
  monitoring_role_arn         = data.terraform_remote_state.iam.outputs.rds_monitoring_role_arn
  enable_performance_insights = var.enable_performance_insights

  common_tags = local.common_tags
}

# Compute Module - Minimal capacity for standby
module "compute" {
  source = "../../modules/compute"

  project_name               = var.project_name
  environment                = local.environment
  aws_region                 = var.aws_region
  vpc_id                     = module.networking.vpc_id
  public_subnet_ids          = module.networking.public_subnet_ids
  private_web_subnet_ids     = module.networking.private_web_subnet_ids
  private_app_subnet_ids     = module.networking.private_app_subnet_ids

  alb_security_group_id      = module.security.alb_security_group_id
  web_security_group_id      = module.security.web_security_group_id
  app_security_group_id      = module.security.app_security_group_id
  bastion_security_group_id  = module.security.bastion_security_group_id

  web_instance_type          = var.web_instance_type
  app_instance_type          = var.app_instance_type
  key_name                   = var.key_name
  ec2_instance_profile_name  = data.terraform_remote_state.iam.outputs.ec2_instance_profile_name

  # Minimal capacity for standby (can be scaled up during failover)
  web_min_size               = var.web_min_size
  web_max_size               = var.web_max_size
  web_desired_capacity       = var.web_desired_capacity
  app_min_size               = var.app_min_size
  app_max_size               = var.app_max_size
  app_desired_capacity       = var.app_desired_capacity

  health_check_path          = var.health_check_path
  enable_deletion_protection = var.enable_deletion_protection
  enable_bastion             = var.enable_bastion

  db_endpoint                = module.database.replica_instance_endpoint != null ? module.database.replica_instance_endpoint : module.database.db_instance_endpoint
  db_name                    = var.db_name
  db_secret_arn              = module.database.db_secret_arn

  common_tags = local.common_tags
}

# Monitoring Module
module "monitoring" {
  source = "../../modules/monitoring"

  project_name               = var.project_name
  environment                = local.environment
  aws_region                 = var.aws_region
  alarm_email_endpoints      = var.alarm_email_endpoints
  log_retention_days         = var.log_retention_days

  alb_arn_suffix             = split("/", module.compute.alb_arn)[1]
  target_group_arn_suffix    = split(":", module.compute.web_target_group_arn)[5]
  web_asg_name               = module.compute.web_asg_name
  app_asg_name               = module.compute.app_asg_name
  web_scale_up_policy_arn    = module.compute.web_scale_up_policy_arn
  web_scale_down_policy_arn  = module.compute.web_scale_down_policy_arn
  db_instance_id             = module.database.replica_instance_id != null ? module.database.replica_instance_id : module.database.db_instance_id

  enable_ec2_alarms          = var.enable_ec2_alarms
  enable_rds_alarms          = var.enable_rds_alarms

  common_tags = local.common_tags
}

# Data source for IAM resources (created globally)
data "terraform_remote_state" "iam" {
  backend = "s3"

  config = {
    bucket = var.terraform_state_bucket
    key    = "global/iam/terraform.tfstate"
    region = var.terraform_state_region
  }
}
