# Database Module - RDS PostgreSQL/MySQL

# Random password for database
resource "random_password" "db_password" {
  length  = 32
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store database credentials in Secrets Manager
resource "aws_secretsmanager_secret" "db_credentials" {
  name_prefix             = "${var.project_name}-${var.environment}-db-"
  description             = "Database credentials for ${var.environment} environment"
  recovery_window_in_days = var.secret_recovery_window

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-db-secret"
    }
  )
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    engine   = var.db_engine
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.db_name
  })
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name_prefix = "${var.project_name}-${var.environment}-"
  description = "Database subnet group for ${var.environment} environment"
  subnet_ids  = var.private_db_subnet_ids

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-db-subnet-group"
    }
  )
}

# DB Parameter Group
resource "aws_db_parameter_group" "main" {
  name_prefix = "${var.project_name}-${var.environment}-"
  family      = var.db_parameter_group_family
  description = "Database parameter group for ${var.environment} environment"

  # PostgreSQL parameters
  dynamic "parameter" {
    for_each = var.db_engine == "postgres" ? [1] : []
    content {
      name  = "log_connections"
      value = "1"
    }
  }

  dynamic "parameter" {
    for_each = var.db_engine == "postgres" ? [1] : []
    content {
      name  = "log_disconnections"
      value = "1"
    }
  }

  # MySQL parameters
  dynamic "parameter" {
    for_each = var.db_engine == "mysql" ? [1] : []
    content {
      name  = "general_log"
      value = "1"
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-db-param-group"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# DB Option Group (for MySQL)
resource "aws_db_option_group" "main" {
  count                    = var.db_engine == "mysql" ? 1 : 0
  name_prefix              = "${var.project_name}-${var.environment}-"
  option_group_description = "Database option group for ${var.environment} environment"
  engine_name              = var.db_engine
  major_engine_version     = split(".", var.db_engine_version)[0]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-db-option-group"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# KMS Key for RDS Encryption
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption in ${var.environment} environment"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-rds-kms"
    }
  )
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.project_name}-${var.environment}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-${var.environment}-db"
  engine         = var.db_engine
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result
  port     = var.db_engine == "postgres" ? 5432 : 3306

  multi_az               = var.is_primary ? var.enable_multi_az : false
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.database_security_group_id]
  parameter_group_name   = aws_db_parameter_group.main.name
  option_group_name      = var.db_engine == "mysql" ? aws_db_option_group.main[0].name : null

  # Backup configuration
  backup_retention_period   = var.backup_retention_period
  backup_window             = var.backup_window
  maintenance_window        = var.maintenance_window
  copy_tags_to_snapshot     = true
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.project_name}-${var.environment}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Enhanced monitoring
  enabled_cloudwatch_logs_exports = var.db_engine == "postgres" ? ["postgresql"] : ["error", "general", "slowquery"]
  monitoring_interval             = var.enable_enhanced_monitoring ? 60 : 0
  monitoring_role_arn             = var.enable_enhanced_monitoring ? var.monitoring_role_arn : null

  # Performance Insights
  performance_insights_enabled    = var.enable_performance_insights
  performance_insights_kms_key_id = var.enable_performance_insights ? aws_kms_key.rds.arn : null
  performance_insights_retention_period = var.enable_performance_insights ? 7 : null

  # Deletion protection
  deletion_protection = var.enable_deletion_protection

  # Auto minor version upgrade
  auto_minor_version_upgrade = true

  # Apply changes immediately (use with caution in production)
  apply_immediately = var.apply_immediately

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-db"
    }
  )

  lifecycle {
    ignore_changes = [
      password,
      final_snapshot_identifier
    ]
  }
}

# Read Replica (for secondary region)
resource "aws_db_instance" "replica" {
  count              = var.is_primary ? 0 : 1
  identifier         = "${var.project_name}-${var.environment}-db-replica"
  replicate_source_db = var.source_db_identifier

  instance_class = var.db_instance_class
  storage_encrypted = true
  kms_key_id     = aws_kms_key.rds.arn

  vpc_security_group_ids = [var.database_security_group_id]
  parameter_group_name   = aws_db_parameter_group.main.name
  option_group_name      = var.db_engine == "mysql" ? aws_db_option_group.main[0].name : null

  # Backup configuration (replicas can have their own backup settings)
  backup_retention_period = var.backup_retention_period
  skip_final_snapshot     = var.skip_final_snapshot

  # Enhanced monitoring
  monitoring_interval = var.enable_enhanced_monitoring ? 60 : 0
  monitoring_role_arn = var.enable_enhanced_monitoring ? var.monitoring_role_arn : null

  # Performance Insights
  performance_insights_enabled    = var.enable_performance_insights
  performance_insights_kms_key_id = var.enable_performance_insights ? aws_kms_key.rds.arn : null

  # Auto minor version upgrade
  auto_minor_version_upgrade = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-db-replica"
    }
  )

  lifecycle {
    ignore_changes = [
      replicate_source_db
    ]
  }
}

# CloudWatch Log Groups for RDS logs
resource "aws_cloudwatch_log_group" "rds" {
  for_each = toset(var.db_engine == "postgres" ? ["postgresql"] : ["error", "general", "slowquery"])

  name              = "/aws/rds/instance/${aws_db_instance.main.identifier}/${each.key}"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-rds-${each.key}-logs"
    }
  )
}
