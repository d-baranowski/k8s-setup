variable "tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
  default     = {
    owner = "utro"
    env   = "may-chang"
  }

  validation {
    condition     = alltrue([for k in keys(var.tags) : can(regex("^[a-z][a-z0-9_-]{0,62}$", k))])
    error_message = "tags keys must be lowercase and match ^[a-z][a-z0-9_-]{0,62}$ (GCP Secret Manager label requirement)."
  }
}

variable "gcp_project_id" {
  description = "GCP project ID where secrets will be stored in Secret Manager"
  type        = string
}

variable "gcp_region" {
    description = "GCP region"
    type        = string
    default     = "europe-central2"
}

variable "create_user" {
  description = "Whether to create an IAM user with static access keys and export them to Google Secret Manager"
  type        = bool
  default     = false
}

variable "external_secrets_output_path" {
  description = "Absolute path to the directory where ExternalSecret YAML files will be written (e.g. path to your GitOps repo)"
  type        = string
  default     = ""
}

variable "external_secrets_namespace" {
  description = "Kubernetes namespace to set on the generated ExternalSecret resources"
  type        = string
  default     = "default"
}

variable "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore to reference in the generated ExternalSecret resources"
  type        = string
  default     = "google-secrets"
}

variable "firebase_authorized_domains" {
  description = "Domains allowed to complete Firebase auth flows (email-link continueUrl, OAuth redirect). Include the customer web host and localhost for dev."
  type        = list(string)
  default     = ["localhost"]
}

variable "enable_google_signin" {
  description = "Enable the Google sign-in IdP. Requires the OAuth web-client id/secret to already be in Secret Manager (run scripts/put-google-oauth-secrets.sh once first)."
  type        = bool
  default     = false
}

variable "aws_region" {
    description = "AWS region to create resources in"
    type        = string
    # eu-central-1 is where the utro-a253e7cf-backups bucket (and the rest of
    # this stack's AWS resources) actually live. The old eu-west-1 default was
    # wrong and caused `import` blocks to report the bucket as non-existent —
    # keep this in sync with the real region or state recovery breaks again.
    default     = "eu-central-1"
}

variable "aws_profile" {
    description = "AWS CLI profile to use for authentication (must have permissions to create the specified resources)"
    type        = string
    default     = "tf-admin"
}
# ---------------------------------------------------------------------------
# Assets service object storage + CDN (UTR-000266)
# ---------------------------------------------------------------------------

variable "assets_staging_bucket_name" {
  description = "S3 bucket for the staging asset store. Bucket names are globally unique across all AWS accounts."
  type        = string
  default     = "utro-assets-staging"
}

variable "assets_prod_bucket_name" {
  description = "S3 bucket for the production asset store. Bucket names are globally unique across all AWS accounts."
  type        = string
  default     = "utro-assets"
}

variable "assets_staging_domain" {
  description = "Hostname the staging CDN serves on. Follows the utro-test naming already on inspi.cloud."
  type        = string
  default     = "utro-test-assets.inspi.cloud"
}

variable "assets_staging_hosted_zone" {
  description = "Cloudflare zone holding the staging assets domain"
  type        = string
  default     = "inspi.cloud"
}

variable "assets_prod_domain" {
  description = "Hostname the production CDN serves on"
  type        = string
  default     = "assets.inspiration-particle.com"
}

variable "assets_prod_hosted_zone" {
  description = "Cloudflare zone holding the production assets domain"
  type        = string
  default     = "inspiration-particle.com"
}

variable "assets_manage_dns" {
  description = "Create the ACM validation records and the CDN CNAMEs in Cloudflare. Requires CLOUDFLARE_API_TOKEN. The CNAMEs must stay DNS-only (not proxied)."
  type        = bool
  default     = true
}

# Separate from create_user, which stays false for the backup bucket. The assets
# service authenticates with static keys because k3s has no OIDC provider for
# IRSA, so this must be true for the service to be able to write anything.
variable "assets_create_user" {
  description = "Create IAM users with static access keys for the assets service and export them to Google Secret Manager"
  type        = bool
  default     = true
}

variable "assets_cluster_manifests_path" {
  description = <<-EOT
    Path to the cluster manifests directory the generated assets ExternalSecret
    files are written into, one per environment subdirectory (relative paths are
    resolved from this stack's directory). Empty disables generation.
  EOT
  type        = string
  default     = "../../clusters/may-chang"
}
