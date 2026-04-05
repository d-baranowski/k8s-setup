# ---------------------------------------------------------------------------
# Push the IAM access keys produced by the module into Google Secret Manager.
# Only created when create_user = true.
# ---------------------------------------------------------------------------

resource "google_secret_manager_secret" "aws_access_key_id" {
  count     = var.create_user ? 1 : 0
  project   = var.gcp_project_id
  secret_id = "mattermost-filestore-aws-access-key-id"

  replication {
    auto {}
  }

  labels = var.tags
}

resource "google_secret_manager_secret_version" "aws_access_key_id" {
  count       = var.create_user ? 1 : 0
  secret      = google_secret_manager_secret.aws_access_key_id[0].id
  secret_data = module.s3_filestore.access_key_id
}

resource "google_secret_manager_secret" "aws_secret_access_key" {
  count     = var.create_user ? 1 : 0
  project   = var.gcp_project_id
  secret_id = "mattermost-filestore-aws-secret-access-key"

  replication {
    auto {}
  }

  labels = var.tags
}

resource "google_secret_manager_secret_version" "aws_secret_access_key" {
  count       = var.create_user ? 1 : 0
  secret      = google_secret_manager_secret.aws_secret_access_key[0].id
  secret_data = module.s3_filestore.secret_access_key
}

# ---------------------------------------------------------------------------
# Export the actual S3 bucket name so Kubernetes can reference it dynamically
# via ExternalSecret rather than hardcoding the random-suffixed name.
# ---------------------------------------------------------------------------

resource "google_secret_manager_secret" "bucket_name" {
  project   = var.gcp_project_id
  secret_id = "mattermost-filestore-bucket-name"

  replication {
    auto {}
  }

  labels = var.tags
}

resource "google_secret_manager_secret_version" "bucket_name" {
  secret      = google_secret_manager_secret.bucket_name.id
  secret_data = module.s3_filestore.bucket_id
}
