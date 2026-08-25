variable "gcp_project_id" {
  description = "GCP project ID where the backup IAM user's keys are stored in Secret Manager"
  type        = string
}

# eu-central-1 on purpose: the utro stack's variables.tf once defaulted to
# eu-west-1, which made every existing resource look absent on plan.
variable "aws_region" {
  description = "AWS region for the backup bucket"
  type        = string
  default     = "eu-central-1"
}

variable "gcp_region" {
  description = "GCP region"
  type        = string
  default     = "europe-central2"
}

variable "tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
  default = {
    owner = "kadis"
    env   = "may-chang"
  }

  validation {
    condition     = alltrue([for k in keys(var.tags) : can(regex("^[a-z][a-z0-9_-]{0,62}$", k))])
    error_message = "tags keys must be lowercase and match ^[a-z][a-z0-9_-]{0,62}$ (GCP Secret Manager label requirement)."
  }
}
