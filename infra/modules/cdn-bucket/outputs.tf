output "bucket_id" {
  description = "Bucket name, i.e. STORAGE_BUCKET"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "Bucket ARN"
  value       = aws_s3_bucket.this.arn
}

output "distribution_id" {
  description = "CloudFront distribution id, for cache invalidations"
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_domain_name" {
  description = "CloudFront domain name, e.g. d111111abcdef8.cloudfront.net"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "public_base_url" {
  description = "Value for the assets service's ASSETS_PUBLIC_BASE_URL"
  value       = "https://${var.domain}"
}

output "acm_certificate_arn" {
  description = "ARN of the validated ACM certificate"
  value       = aws_acm_certificate_validation.this.certificate_arn
}

output "iam_user_name" {
  description = "IAM user the assets service authenticates as (empty if create_user = false)"
  value       = length(aws_iam_user.writer) > 0 ? aws_iam_user.writer[0].name : ""
}

output "access_key_id" {
  description = "Access key id for the writer user (empty if create_user = false)"
  value       = length(aws_iam_access_key.writer) > 0 ? aws_iam_access_key.writer[0].id : ""
  sensitive   = true
}

output "secret_access_key" {
  description = "Secret access key for the writer user (empty if create_user = false)"
  value       = length(aws_iam_access_key.writer) > 0 ? aws_iam_access_key.writer[0].secret : ""
  sensitive   = true
}
