variable "name" {
  description = "Short name for this asset store, used as the resource name prefix (e.g. utro-assets-staging)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,48}$", var.name))
    error_message = "name must be lowercase alphanumeric with hyphens, starting with a letter."
  }
}

variable "bucket_name" {
  description = "Explicit S3 bucket name. Bucket names are globally unique across all AWS accounts."
  type        = string
}

variable "domain" {
  description = "Public hostname the CDN serves on, e.g. assets.example.com"
  type        = string
}

variable "hosted_zone" {
  description = "Cloudflare zone that already holds the domain, e.g. inspi.cloud"
  type        = string
}

variable "manage_dns" {
  description = "Create the ACM validation records and the CDN CNAME in Cloudflare. The CNAME must stay DNS-only (not proxied)."
  type        = bool
  default     = true
}

variable "price_class" {
  description = "CloudFront price class. PriceClass_100 is NA + EU, which covers the audience at the lowest cost."
  type        = string
  default     = "PriceClass_100"
}

variable "cache_control" {
  description = <<-EOT
    Cache-Control applied to every object served through the CDN.

    The assets service writes objects with a Content-Type but no Cache-Control,
    and CloudFront never reaches the service's own download handler which would
    otherwise set one. Without this header browsers fall back to heuristic
    caching. Renditions are immutable — a new upload gets a new id — so a long
    max-age is safe.
  EOT
  type        = string
  default     = "public, max-age=31536000, immutable"
}

variable "create_user" {
  description = "Create an IAM user with static access keys for the assets service to write objects with"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
