module "s3_filestore" {
  source = "../modules/s3-backup"

  name_prefix       = "mattermost"
  bucket_name       = "" # auto-generates a unique name with random suffix
  enable_versioning = false
  lifecycle_rules   = []
  tags              = var.tags

  # No IRSA needed - using static IAM user credentials
  create_role       = false
  oidc_provider_arn = ""
  oidc_sub_key      = "oidc.eks.amazonaws.com/id/<id>:sub"
  sa_name           = ""
  sa_namespace      = ""

  # Create IAM user with static access keys for Mattermost filestore
  create_user = var.create_user
}
