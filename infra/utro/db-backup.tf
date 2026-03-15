# Minimal example infra to demonstrate provider usage and outputs
# This file intentionally keeps resources small and safe for examples.

module "s3_backup" {
  source = "../modules/s3-backup"

  name_prefix       = "utro"
  bucket_name       = "utro-a253e7cf-backups"
  enable_versioning = true
  lifecycle_rules   = []
  tags              = var.tags

  # IRSA: set create_role = true and supply oidc_provider_arn, oidc_sub_key, sa_name, sa_namespace
  create_role       = false
  oidc_provider_arn = ""
  oidc_sub_key      = "oidc.eks.amazonaws.com/id/<id>:sub"
  sa_name           = ""
  sa_namespace      = ""

  # Set create_user = true to generate an IAM user + access keys for static credential auth (e.g. CNPG barman)
  create_user = var.create_user
}
