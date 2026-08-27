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

output "combined_external_secret_path" {
  description = "Path of the generated combined ExternalSecret YAML (postgres-backup-aws-creds) written into the GitOps repo"
  value       = var.create_user ? local_file.external_secret_combined_aws_creds[0].filename : ""
}


# ---------------------------------------------------------------------------
# Assets service object storage + CDN
# ---------------------------------------------------------------------------

output "assets_distribution_ids" {
  description = "CloudFront distribution ids, for cache invalidations"
  value = {
    staging = module.assets_staging.distribution_id
    prod    = module.assets_prod.distribution_id
  }
}

output "assets_distribution_domain_names" {
  description = "CloudFront domain names the CDN CNAMEs point at"
  value = {
    staging = module.assets_staging.distribution_domain_name
    prod    = module.assets_prod.distribution_domain_name
  }
}

# Everything the assets statefulsets need that is not a secret. The credentials
# arrive separately through External Secrets.
output "assets_service_env" {
  description = "Non-secret env values for the assets statefulsets"
  value = {
    staging = {
      STORAGE_ENDPOINT       = "s3.${var.aws_region}.amazonaws.com"
      STORAGE_BUCKET         = module.assets_staging.bucket_id
      STORAGE_REGION         = var.aws_region
      STORAGE_USE_SSL        = "true"
      ASSETS_PUBLIC_BASE_URL = module.assets_staging.public_base_url
    }
    prod = {
      STORAGE_ENDPOINT       = "s3.${var.aws_region}.amazonaws.com"
      STORAGE_BUCKET         = module.assets_prod.bucket_id
      STORAGE_REGION         = var.aws_region
      STORAGE_USE_SSL        = "true"
      ASSETS_PUBLIC_BASE_URL = module.assets_prod.public_base_url
    }
  }
}
