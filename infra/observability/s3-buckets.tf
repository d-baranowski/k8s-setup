module "s3_loki" {
  source = "../modules/s3-backup"

  name_prefix       = "loki"
  # Explicit bucket name so Loki helm values can reference it literally
  # without runtime env interpolation. AWS S3 bucket names are globally
  # unique — change this if the name is already taken.
  bucket_name       = "utro-loki-chunks"
  enable_versioning = false
  lifecycle_rules   = []
  tags              = var.tags

  create_role       = false
  oidc_provider_arn = ""
  oidc_sub_key      = "oidc.eks.amazonaws.com/id/<id>:sub"
  sa_name           = ""
  sa_namespace      = ""

  create_user = var.create_user
}

module "s3_tempo" {
  source = "../modules/s3-backup"

  name_prefix       = "tempo"
  bucket_name       = "utro-tempo-traces"
  enable_versioning = false
  lifecycle_rules   = []
  tags              = var.tags

  create_role       = false
  oidc_provider_arn = ""
  oidc_sub_key      = "oidc.eks.amazonaws.com/id/<id>:sub"
  sa_name           = ""
  sa_namespace      = ""

  create_user = var.create_user
}
