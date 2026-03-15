output "bucket_id" {
  description = "S3 backup bucket name"
  value       = module.s3_backup.bucket_id
}

output "bucket_arn" {
  description = "S3 backup bucket ARN"
  value       = module.s3_backup.bucket_arn
}

output "policy_arn" {
  description = "IAM policy ARN granting read/write access to the backup bucket"
  value       = module.s3_backup.policy_arn
}

output "irsa_role_arn" {
  description = "IRSA role ARN (empty if create_role = false)"
  value       = module.s3_backup.irsa_role_arn
}

output "iam_user_name" {
  description = "IAM user name created for static credentials (empty if create_user = false)"
  value       = module.s3_backup.iam_user_name
}

output "gcp_secret_access_key_id_name" {
  description = "GCP Secret Manager secret ID holding the AWS access key ID (empty if create_user = false)"
  value       = length(google_secret_manager_secret.aws_access_key_id) > 0 ? google_secret_manager_secret.aws_access_key_id[0].secret_id : ""
}

output "gcp_secret_access_key_name" {
  description = "GCP Secret Manager secret ID holding the AWS secret access key (empty if create_user = false)"
  value       = length(google_secret_manager_secret.aws_secret_access_key) > 0 ? google_secret_manager_secret.aws_secret_access_key[0].secret_id : ""
}
