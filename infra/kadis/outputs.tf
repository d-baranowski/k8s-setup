output "bucket_id" {
  description = "Backup bucket name"
  value       = module.s3_backup.bucket_id
}

output "bucket_arn" {
  description = "Backup bucket ARN"
  value       = module.s3_backup.bucket_arn
}

output "iam_user_name" {
  description = "IAM user the backup jobs authenticate as"
  value       = module.s3_backup.iam_user_name
}

output "gsm_access_key_id_secret" {
  description = "Secret Manager id holding the access key ID"
  value       = google_secret_manager_secret.aws_access_key_id.secret_id
}

output "gsm_secret_access_key_secret" {
  description = "Secret Manager id holding the secret access key"
  value       = google_secret_manager_secret.aws_secret_access_key.secret_id
}
