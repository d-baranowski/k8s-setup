# The shared secret the admin UI's server presents to the admin gateway
# (UTR-000892). The gateway believes X-User-Id only from a caller holding it,
# so the value is generated here and never typed by hand. The ExternalSecrets
# that read it are committed alongside the statefulsets:
# clusters/may-chang/{utr-staging,utro}/*-gateway-bff-secret.yaml.

locals {
  gateway_bff_environments = toset(["staging", "prod"])
}

resource "random_password" "gateway_bff" {
  for_each = local.gateway_bff_environments

  length  = 48
  special = false
}

resource "google_secret_manager_secret" "gateway_bff" {
  for_each = local.gateway_bff_environments

  project   = var.gcp_project_id
  secret_id = "utro-gateway-bff-${each.key}-secret"

  replication {
    auto {}
  }

  labels = var.tags
}

resource "google_secret_manager_secret_version" "gateway_bff" {
  for_each = local.gateway_bff_environments

  secret      = google_secret_manager_secret.gateway_bff[each.key].id
  secret_data = random_password.gateway_bff[each.key].result
}
