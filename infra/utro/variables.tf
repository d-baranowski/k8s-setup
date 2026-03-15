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

variable "aws_region" {
    description = "AWS region to create resources in"
    type        = string
    default     = "eu-west-1"
}

variable "aws_profile" {
    description = "AWS CLI profile to use for authentication (must have permissions to create the specified resources)"
    type        = string
    default     = "tf-admin"
}