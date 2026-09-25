output "bucket_id" {
  description = "Bucket name"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "Bucket ARN"
  value       = aws_s3_bucket.this.arn
}

output "writer_policy_arn" {
  description = "IAM policy granting list and object read/write/delete on the bucket"
  value       = aws_iam_policy.writer.arn
}
