variable "name_prefix" {
  description = "Prefix used for resource names"
  type        = string
  default     = "utro"
}

variable "bucket_name" {
  description = "Optional explicit bucket name. If empty a name is generated from name_prefix"
  type        = string
  default     = ""
}

variable "enable_versioning" {
  description = "Enable S3 versioning"
  type        = bool
  default     = true
}

variable "lifecycle_rules" {
  description = "List of lifecycle rules to apply to the bucket"
  type        = list(any)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "create_role" {
  description = "Whether to create an IAM role for IRSA web identity"
  type        = bool
  default     = false
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider to use for assume role with web identity"
  type        = string
  default     = ""
}

variable "oidc_sub_key" {
  description = "The key used in the OIDC provider to match the subject claim (eg: 'oidc.eks.amazonaws.com/id/<id>:sub')"
  type        = string
  default     = "oidc.eks.amazonaws.com/id/<id>:sub"
}

variable "sa_name" {
  description = "Service account name to bind role to (for IRSA)"
  type        = string
  default     = ""
}

variable "sa_namespace" {
  description = "Service account namespace to bind role to"
  type        = string
  default     = ""
}

variable "create_user" {
  description = "Whether to create an IAM user with static access keys (keys are exposed as sensitive outputs)"
  type        = bool
  default     = false
}

