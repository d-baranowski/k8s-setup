variable "name" {
  description = "Resource name prefix, used for the writer policy (e.g. utro-assets-staging-documents)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,48}$", var.name))
    error_message = "name must be lowercase alphanumeric with hyphens, starting with a letter."
  }
}

variable "bucket_name" {
  description = "Explicit S3 bucket name. Bucket names are globally unique across all AWS accounts."
  type        = string

  # Presigned URLs are virtual-hosted (bucket.s3.region.amazonaws.com); a dot
  # in the name breaks the wildcard TLS certificate.
  validation {
    condition     = !strcontains(var.bucket_name, ".")
    error_message = "bucket_name must not contain dots."
  }
}

variable "versioning" {
  description = "Keep overwritten and deleted objects as noncurrent versions"
  type        = bool
  default     = false
}

variable "noncurrent_version_days" {
  description = "Days a noncurrent version is kept before it expires. Only used with versioning."
  type        = number
  default     = 90
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
