# Credentials for the assets service: IAM keys into Google Secret Manager, and
# an ExternalSecret per environment rendered into that environment's cluster
# directory.
#
# for_each rather than a block per environment: the two differ only by name, and
# the copy-per-resource style elsewhere in this stack already runs to four
# near-identical blocks for a single bucket.
#
# Only the credentials live here. Bucket names and CDN URLs are not secret and
# are consumed as plain env values in the statefulsets — see outputs.tf.

locals {
  # Keys must be statically known and free of sensitive values, so this map
  # carries only configuration. The credentials are looked up separately below.
  #
  # Both environments run in the `default` namespace on may-chang and are kept
  # apart by resource name prefix (utro-core vs utr-staging-core), so the
  # generated secrets follow that convention. Without the prefix the two
  # ExternalSecrets would be the same object and would fight over credentials.
  assets_environments = {
    staging = {
      prefix      = "utr-staging"
      cluster_dir = "utr-staging"
    }
    prod = {
      prefix      = "utro"
      cluster_dir = "utro"
    }
  }

  assets_secret_environments = var.assets_create_user ? local.assets_environments : {}

  assets_access_key_ids = {
    staging = module.assets_staging.access_key_id
    prod    = module.assets_prod.access_key_id
  }

  assets_secret_access_keys = {
    staging = module.assets_staging.secret_access_key
    prod    = module.assets_prod.secret_access_key
  }

  assets_manifests_path = startswith(var.assets_cluster_manifests_path, "/") ? var.assets_cluster_manifests_path : "${path.root}/${var.assets_cluster_manifests_path}"

  assets_manifest_environments = var.assets_cluster_manifests_path != "" ? local.assets_secret_environments : {}
}

resource "google_secret_manager_secret" "assets_access_key_id" {
  for_each = local.assets_secret_environments

  project   = var.gcp_project_id
  secret_id = "utro-assets-${each.key}-s3-access-key-id"

  replication {
    auto {}
  }

  labels = var.tags
}

resource "google_secret_manager_secret_version" "assets_access_key_id" {
  for_each = local.assets_secret_environments

  secret      = google_secret_manager_secret.assets_access_key_id[each.key].id
  secret_data = local.assets_access_key_ids[each.key]
}

resource "google_secret_manager_secret" "assets_secret_access_key" {
  for_each = local.assets_secret_environments

  project   = var.gcp_project_id
  secret_id = "utro-assets-${each.key}-s3-secret-access-key"

  replication {
    auto {}
  }

  labels = var.tags
}

resource "google_secret_manager_secret_version" "assets_secret_access_key" {
  for_each = local.assets_secret_environments

  secret      = google_secret_manager_secret.assets_secret_access_key[each.key].id
  secret_data = local.assets_secret_access_keys[each.key]
}

# The secretKey names are the assets service's own envconfig names, so the
# statefulset can pull them in with envFrom rather than restating every key as
# a valueFrom block.
resource "local_file" "assets_s3_external_secret" {
  for_each = local.assets_manifest_environments

  filename = "${local.assets_manifests_path}/${each.value.cluster_dir}/${each.value.prefix}-assets-s3-credentials.yaml"
  content  = <<-EOT
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: ${each.value.prefix}-assets-s3-credentials
      namespace: ${var.external_secrets_namespace}
    spec:
      refreshInterval: 1h
      secretStoreRef:
        kind: ClusterSecretStore
        name: ${var.cluster_secret_store_name}
      target:
        name: ${each.value.prefix}-assets-s3-credentials
        creationPolicy: Owner
        deletionPolicy: Retain
      data:
        - secretKey: STORAGE_ACCESS_KEY
          remoteRef:
            key: ${google_secret_manager_secret.assets_access_key_id[each.key].secret_id}
            version: latest
        - secretKey: STORAGE_SECRET_KEY
          remoteRef:
            key: ${google_secret_manager_secret.assets_secret_access_key[each.key].secret_id}
            version: latest
  EOT
}
