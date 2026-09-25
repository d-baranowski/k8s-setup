# Private document storage for the assets service (UTR-000866): therapy and
# session documents, and customers' bank-transfer confirmations.
#
# Same split as assets.tf — one bucket per environment — and the same IAM user,
# because the service signs both of its buckets with one key pair.
#
# Prod keeps versions: these are payment evidence, and core's orphan pass
# deletes blobs, so a wrong delete must be recoverable.

module "documents_staging" {
  source = "../modules/private-bucket"

  name        = "utro-assets-staging-documents"
  bucket_name = var.documents_staging_bucket_name
  tags        = var.tags
}

module "documents_prod" {
  source = "../modules/private-bucket"

  name                    = "utro-assets-prod-documents"
  bucket_name             = var.documents_prod_bucket_name
  versioning              = true
  noncurrent_version_days = var.documents_prod_noncurrent_version_days
  tags                    = var.tags
}

resource "aws_iam_user_policy_attachment" "documents_staging" {
  count      = var.assets_create_user ? 1 : 0
  user       = module.assets_staging.iam_user_name
  policy_arn = module.documents_staging.writer_policy_arn
}

resource "aws_iam_user_policy_attachment" "documents_prod" {
  count      = var.assets_create_user ? 1 : 0
  user       = module.assets_prod.iam_user_name
  policy_arn = module.documents_prod.writer_policy_arn
}
