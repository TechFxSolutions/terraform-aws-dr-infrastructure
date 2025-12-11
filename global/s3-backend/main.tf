# S3 Backend for Terraform State
# This must be deployed first before other infrastructure

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Random suffix for unique bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-terraform-state-${random_id.bucket_suffix.hex}"

  tags = merge(
    var.common_tags,
    {
      Name    = "${var.project_name}-terraform-state"
      Purpose = "Terraform state storage"
    }
  )

  lifecycle {
    prevent_destroy = true
  }
}

# Enable versioning for state file history
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.project_name}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(
    var.common_tags,
    {
      Name    = "${var.project_name}-terraform-locks"
      Purpose = "Terraform state locking"
    }
  )

  lifecycle {
    prevent_destroy = true
  }
}

# Output instructions for backend configuration
resource "local_file" "backend_config" {
  filename = "${path.module}/backend-config.txt"
  content  = <<-EOT
    # Terraform Backend Configuration
    # Add this to your terraform block in main.tf:

    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.terraform_state.id}"
        key            = "ENV_NAME/terraform.tfstate"  # Replace ENV_NAME with primary/secondary
        region         = "${var.aws_region}"
        dynamodb_table = "${aws_dynamodb_table.terraform_locks.id}"
        encrypt        = true
      }
    }

    # Or use backend config file:
    # terraform init -backend-config="bucket=${aws_s3_bucket.terraform_state.id}" \
    #                -backend-config="key=primary/terraform.tfstate" \
    #                -backend-config="region=${var.aws_region}" \
    #                -backend-config="dynamodb_table=${aws_dynamodb_table.terraform_locks.id}" \
    #                -backend-config="encrypt=true"
  EOT
}
