# Object storage and CDN for the assets service (UTR-000266).
#
# One store per environment. Separate buckets and separate credentials so a
# staging bug cannot reach production bytes — the two environments share the
# `default` namespace on may-chang and are kept apart by name prefix, which
# makes storage the only place real isolation can be enforced.

module "assets_staging" {
  source = "../modules/cdn-bucket"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name        = "utro-assets-staging"
  bucket_name = var.assets_staging_bucket_name
  domain      = var.assets_staging_domain
  hosted_zone = var.assets_staging_hosted_zone
  manage_dns  = var.assets_manage_dns
  create_user = var.assets_create_user
  tags        = var.tags
}

module "assets_prod" {
  source = "../modules/cdn-bucket"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name        = "utro-assets-prod"
  bucket_name = var.assets_prod_bucket_name
  domain      = var.assets_prod_domain
  hosted_zone = var.assets_prod_hosted_zone
  manage_dns  = var.assets_manage_dns
  create_user = var.assets_create_user
  tags        = var.tags
}
