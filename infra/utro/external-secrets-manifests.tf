// ---------------------------------------------------------------------------
// Render ExternalSecret YAML files to disk so they can be committed into the
// GitOps repo. Only written when create_user = true.
// Supports both absolute paths and paths relative to the root module directory.
// ---------------------------------------------------------------------------

locals {
  external_secrets_path = startswith(var.external_secrets_output_path, "/") ? var.external_secrets_output_path : "${path.root}/${var.external_secrets_output_path}"
}

resource "local_file" "external_secret_access_key_id" {
  count    = var.create_user ? 1 : 0
  filename = "${local.external_secrets_path}/${module.s3_backup.bucket_id}-aws-access-key-id.yaml"
  content  = <<-EOT
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: ${module.s3_backup.bucket_id}-aws-access-key-id
      namespace: ${var.external_secrets_namespace}
    spec:
      refreshInterval: 1h
      secretStoreRef:
        kind: ClusterSecretStore
        name: ${var.cluster_secret_store_name}
      target:
        name: ${module.s3_backup.bucket_id}-aws-access-key-id
        creationPolicy: Owner
        deletionPolicy: Retain
      data:
        - secretKey: value
          remoteRef:
            key: ${google_secret_manager_secret.aws_access_key_id[0].secret_id}
            version: latest
  EOT
}

resource "local_file" "external_secret_secret_access_key" {
  count    = var.create_user ? 1 : 0
  filename = "${local.external_secrets_path}/${module.s3_backup.bucket_id}-aws-secret-access-key.yaml"
  content  = <<-EOT
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: ${module.s3_backup.bucket_id}-aws-secret-access-key
      namespace: ${var.external_secrets_namespace}
    spec:
      refreshInterval: 1h
      secretStoreRef:
        kind: ClusterSecretStore
        name: ${var.cluster_secret_store_name}
      target:
        name: ${module.s3_backup.bucket_id}-aws-secret-access-key
        creationPolicy: Owner
        deletionPolicy: Retain
      data:
        - secretKey: value
          remoteRef:
            key: ${google_secret_manager_secret.aws_secret_access_key[0].secret_id}
            version: latest
  EOT
}

// ---------------------------------------------------------------------------
// Combined ExternalSecret that surfaces both AWS keys into a single K8s secret.
// This secret is referenced by:
//   - the Postgres cluster's spec.env (WAL archiving / Spilo)
//   - the operator logical-backup cronjob (logical_backup_cronjob_environment_secret)
// ---------------------------------------------------------------------------

resource "local_file" "external_secret_combined_aws_creds" {
  count    = var.create_user ? 1 : 0
  filename = "${local.external_secrets_path}/postgres-backup-aws-creds.yaml"
  content  = <<-EOT
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: postgres-backup-aws-creds
      namespace: ${var.external_secrets_namespace}
    spec:
      refreshInterval: 1h
      secretStoreRef:
        kind: ClusterSecretStore
        name: ${var.cluster_secret_store_name}
      target:
        name: postgres-backup-aws-creds
        creationPolicy: Owner
        deletionPolicy: Retain
      data:
        - secretKey: AWS_ACCESS_KEY_ID
          remoteRef:
            key: ${google_secret_manager_secret.aws_access_key_id[0].secret_id}
            version: latest
        - secretKey: AWS_SECRET_ACCESS_KEY
          remoteRef:
            key: ${google_secret_manager_secret.aws_secret_access_key[0].secret_id}
            version: latest
  EOT
}

