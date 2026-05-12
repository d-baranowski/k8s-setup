# Render ExternalSecret YAML files to disk so they can be committed into the
# GitOps repo. Only written when create_user = true (Loki/Tempo creds) and
# always for bucket names.

locals {
  external_secrets_path = startswith(var.external_secrets_output_path, "/") ? var.external_secrets_output_path : "${path.root}/${var.external_secrets_output_path}"
}

# ----- Loki S3 credentials (combined AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY + BUCKET) -----
resource "local_file" "loki_s3_external_secret" {
  count    = var.create_user ? 1 : 0
  filename = "${local.external_secrets_path}/loki-s3-credentials.yaml"
  content  = <<-EOT
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: loki-s3-credentials
      namespace: ${var.external_secrets_namespace}
    spec:
      refreshInterval: 1h
      secretStoreRef:
        kind: ClusterSecretStore
        name: ${var.cluster_secret_store_name}
      target:
        name: loki-s3-credentials
        creationPolicy: Owner
        deletionPolicy: Retain
      data:
        - secretKey: AWS_ACCESS_KEY_ID
          remoteRef:
            key: ${google_secret_manager_secret.loki_aws_access_key_id[0].secret_id}
            version: latest
        - secretKey: AWS_SECRET_ACCESS_KEY
          remoteRef:
            key: ${google_secret_manager_secret.loki_aws_secret_access_key[0].secret_id}
            version: latest
  EOT
}

# ----- Tempo S3 credentials -----
resource "local_file" "tempo_s3_external_secret" {
  count    = var.create_user ? 1 : 0
  filename = "${local.external_secrets_path}/tempo-s3-credentials.yaml"
  content  = <<-EOT
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: tempo-s3-credentials
      namespace: ${var.external_secrets_namespace}
    spec:
      refreshInterval: 1h
      secretStoreRef:
        kind: ClusterSecretStore
        name: ${var.cluster_secret_store_name}
      target:
        name: tempo-s3-credentials
        creationPolicy: Owner
        deletionPolicy: Retain
      data:
        - secretKey: AWS_ACCESS_KEY_ID
          remoteRef:
            key: ${google_secret_manager_secret.tempo_aws_access_key_id[0].secret_id}
            version: latest
        - secretKey: AWS_SECRET_ACCESS_KEY
          remoteRef:
            key: ${google_secret_manager_secret.tempo_aws_secret_access_key[0].secret_id}
            version: latest
  EOT
}
