# ---------------------------------------------------------------------------
# Push the backup IAM user's access keys into Google Secret Manager, where
# External Secrets picks them up for the sqlserver namespace. Mirrors
# infra/utro/gcp-secrets.tf, minus its create_user guard — this stack always
# creates the user.
# ---------------------------------------------------------------------------

resource "google_secret_manager_secret" "aws_access_key_id" {
  project   = var.gcp_project_id
  secret_id = "${module.s3_backup.bucket_id}-aws-access-key-id"

  replication {
    auto {}
  }

  labels = var.tags
}

resource "google_secret_manager_secret_version" "aws_access_key_id" {
  secret      = google_secret_manager_secret.aws_access_key_id.id
  secret_data = module.s3_backup.access_key_id
}

resource "google_secret_manager_secret" "aws_secret_access_key" {
  project   = var.gcp_project_id
  secret_id = "${module.s3_backup.bucket_id}-aws-secret-access-key"

  replication {
    auto {}
  }

  labels = var.tags
}

resource "google_secret_manager_secret_version" "aws_secret_access_key" {
  secret      = google_secret_manager_secret.aws_secret_access_key.id
  secret_data = module.s3_backup.secret_access_key
}
