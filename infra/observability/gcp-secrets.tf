# Push the IAM access keys produced by the s3-backup modules into Google Secret
# Manager. Only created when create_user = true.
# Each bucket gets its own access key id + secret access key + bucket name secrets.

# ----- Loki -----
resource "google_secret_manager_secret" "loki_aws_access_key_id" {
  count     = var.create_user ? 1 : 0
  project   = var.gcp_project_id
  secret_id = "loki-s3-aws-access-key-id"

  replication {
    auto {}
  }

  labels = var.tags
}

resource "google_secret_manager_secret_version" "loki_aws_access_key_id" {
  count       = var.create_user ? 1 : 0
  secret      = google_secret_manager_secret.loki_aws_access_key_id[0].id
  secret_data = module.s3_loki.access_key_id
}

resource "google_secret_manager_secret" "loki_aws_secret_access_key" {
  count     = var.create_user ? 1 : 0
  project   = var.gcp_project_id
  secret_id = "loki-s3-aws-secret-access-key"

  replication {
    auto {}
  }

  labels = var.tags
}

resource "google_secret_manager_secret_version" "loki_aws_secret_access_key" {
  count       = var.create_user ? 1 : 0
  secret      = google_secret_manager_secret.loki_aws_secret_access_key[0].id
  secret_data = module.s3_loki.secret_access_key
}

# ----- Tempo -----
resource "google_secret_manager_secret" "tempo_aws_access_key_id" {
  count     = var.create_user ? 1 : 0
  project   = var.gcp_project_id
  secret_id = "tempo-s3-aws-access-key-id"

  replication {
    auto {}
  }

  labels = var.tags
}

resource "google_secret_manager_secret_version" "tempo_aws_access_key_id" {
  count       = var.create_user ? 1 : 0
  secret      = google_secret_manager_secret.tempo_aws_access_key_id[0].id
  secret_data = module.s3_tempo.access_key_id
}

resource "google_secret_manager_secret" "tempo_aws_secret_access_key" {
  count     = var.create_user ? 1 : 0
  project   = var.gcp_project_id
  secret_id = "tempo-s3-aws-secret-access-key"

  replication {
    auto {}
  }

  labels = var.tags
}

resource "google_secret_manager_secret_version" "tempo_aws_secret_access_key" {
  count       = var.create_user ? 1 : 0
  secret      = google_secret_manager_secret.tempo_aws_secret_access_key[0].id
  secret_data = module.s3_tempo.secret_access_key
}
