# ---------------------------------------------------------------------------
# Push the IAM access keys produced by the module into Google Secret Manager.
# Only created when create_user = true.
# ---------------------------------------------------------------------------

resource "google_secret_manager_secret" "aws_access_key_id" {
  count     = var.create_user ? 1 : 0
  project   = var.gcp_project_id
  secret_id = "${module.s3_backup.bucket_id}-aws-access-key-id"

  replication {
    auto {}
  }

  labels = var.tags
}

resource "google_secret_manager_secret_version" "aws_access_key_id" {
  count       = var.create_user ? 1 : 0
  secret      = google_secret_manager_secret.aws_access_key_id[0].id
  secret_data = module.s3_backup.access_key_id
}

resource "google_secret_manager_secret" "aws_secret_access_key" {
  count     = var.create_user ? 1 : 0
  project   = var.gcp_project_id
  secret_id = "${module.s3_backup.bucket_id}-aws-secret-access-key"

  replication {
    auto {}
  }

  labels = var.tags
}

resource "google_secret_manager_secret_version" "aws_secret_access_key" {
  count       = var.create_user ? 1 : 0
  secret      = google_secret_manager_secret.aws_secret_access_key[0].id
  secret_data = module.s3_backup.secret_access_key
}


