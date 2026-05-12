output "loki_bucket_id" {
  description = "Loki S3 bucket name"
  value       = module.s3_loki.bucket_id
}

output "tempo_bucket_id" {
  description = "Tempo S3 bucket name"
  value       = module.s3_tempo.bucket_id
}

output "loki_iam_user_name" {
  description = "Loki IAM user name (empty if create_user = false)"
  value       = module.s3_loki.iam_user_name
}

output "tempo_iam_user_name" {
  description = "Tempo IAM user name (empty if create_user = false)"
  value       = module.s3_tempo.iam_user_name
}
