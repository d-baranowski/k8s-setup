# import-s3-backup.tf — bring the already-existing s3_backup resources back
# into Terraform state.
#
# WHY THIS EXISTS: the local terraform.tfstate that tracked these was lost
# (no remote backend was ever configured; state was a gitignored local file).
# The resources themselves still exist in AWS account 277265293752 — verified
# by their `terraform = "true"` default tag — so we re-adopt them via `import`
# rather than recreating (which would collide with BucketAlreadyOwnedByYou).
#
# Values resolved 2026-07-16:
#   bucket name        → utro-a253e7cf-backups   (aws s3api head-bucket)
#   backup policy ARN  → arn:aws:iam::277265293752:policy/utro-s3-backup-policy
#                        (aws iam list-policies --scope Local)
#
# These 5 blocks match the resources the s3_backup module creates when
# create_role = false and create_user = false (the current db-backup.tf
# settings). Once a clean apply adopts them, these blocks are no-ops and may
# be deleted — harmless to leave as bootstrap documentation, mirroring
# ci-fleet-imports.tf.

# ─── S3 bucket + its sub-resource configs ───────────────────────────────────
# S3 bucket sub-resources (versioning / SSE / public-access-block) all use the
# bucket name as their import ID.

import {
  to = module.s3_backup.aws_s3_bucket.this
  id = "utro-a253e7cf-backups"
}

import {
  to = module.s3_backup.aws_s3_bucket_server_side_encryption_configuration.this
  id = "utro-a253e7cf-backups"
}

import {
  to = module.s3_backup.aws_s3_bucket_versioning.this
  id = "utro-a253e7cf-backups"
}

import {
  to = module.s3_backup.aws_s3_bucket_public_access_block.this
  id = "utro-a253e7cf-backups"
}

# ─── IAM policy ─────────────────────────────────────────────────────────────
# IAM policy import ID is the full ARN.

import {
  to = module.s3_backup.aws_iam_policy.s3_backup_policy
  id = "arn:aws:iam::277265293752:policy/utro-s3-backup-policy"
}
