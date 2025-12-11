# Storage Module Outputs

output "logs_bucket_id" {
  description = "ID of the logs S3 bucket"
  value       = aws_s3_bucket.logs.id
}

output "logs_bucket_arn" {
  description = "ARN of the logs S3 bucket"
  value       = aws_s3_bucket.logs.arn
}

output "backups_bucket_id" {
  description = "ID of the backups S3 bucket"
  value       = aws_s3_bucket.backups.id
}

output "backups_bucket_arn" {
  description = "ARN of the backups S3 bucket"
  value       = aws_s3_bucket.backups.arn
}

output "assets_bucket_id" {
  description = "ID of the assets S3 bucket"
  value       = var.create_assets_bucket ? aws_s3_bucket.assets[0].id : null
}

output "assets_bucket_arn" {
  description = "ARN of the assets S3 bucket"
  value       = var.create_assets_bucket ? aws_s3_bucket.assets[0].arn : null
}

output "s3_kms_key_id" {
  description = "ID of the KMS key for S3 encryption"
  value       = aws_kms_key.s3.id
}

output "s3_kms_key_arn" {
  description = "ARN of the KMS key for S3 encryption"
  value       = aws_kms_key.s3.arn
}
