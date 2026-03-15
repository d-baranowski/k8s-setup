output "bucket_id" {
  description = "Bucket name"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "Bucket ARN"
  value       = aws_s3_bucket.this.arn
}

output "policy_arn" {
  description = "IAM policy ARN allowing access to the bucket"
  value       = aws_iam_policy.s3_backup_policy.arn
}

output "irsa_role_arn" {
  description = "IRSA role ARN (empty if create_role = false)"
  value       = length(aws_iam_role.irsa_role) > 0 ? aws_iam_role.irsa_role[0].arn : ""
}

output "iam_user_name" {
  description = "IAM user name (empty if create_user = false)"
  value       = length(aws_iam_user.backup_user) > 0 ? aws_iam_user.backup_user[0].name : ""
}

output "access_key_id" {
  description = "AWS access key ID for the backup IAM user (empty if create_user = false)"
  value       = length(aws_iam_access_key.backup_user_key) > 0 ? aws_iam_access_key.backup_user_key[0].id : ""
  sensitive   = true
}

output "secret_access_key" {
  description = "AWS secret access key for the backup IAM user (empty if create_user = false)"
  value       = length(aws_iam_access_key.backup_user_key) > 0 ? aws_iam_access_key.backup_user_key[0].secret : ""
  sensitive   = true
}
