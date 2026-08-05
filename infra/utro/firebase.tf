# ---------------------------------------------------------------------------
# Firebase Auth / Google Identity Platform for the customer-facing app.
#
# Customers authenticate with Firebase (passwordless email link + Google) and
# their ID tokens are verified by the customer-gateway. This file provisions the
# Identity Platform config, the Firebase web app (for the frontend SDK config),
# and a least-privilege service account whose key the gateway uses to verify
# tokens (incl. revocation checks). Nothing here is applied by CI — run manually.
# ---------------------------------------------------------------------------

# --- APIs ---------------------------------------------------------------------

resource "google_project_service" "identitytoolkit" {
  project                    = var.gcp_project_id
  service                    = "identitytoolkit.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_project_service" "firebase" {
  project                    = var.gcp_project_id
  service                    = "firebase.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

# --- Identity Platform config -------------------------------------------------

# Enables Identity Platform on the project and turns on passwordless email
# (email-link) sign-in. password_required = false is what selects email-link
# rather than email+password.
resource "google_identity_platform_config" "auth" {
  provider = google-beta
  project  = var.gcp_project_id

  sign_in {
    allow_duplicate_emails = false

    email {
      enabled           = true
      password_required = false
    }
  }

  authorized_domains = var.firebase_authorized_domains

  depends_on = [google_project_service.identitytoolkit]
}

# Google social sign-in. Only created when an OAuth client is supplied, so the
# base config applies cleanly before you've set up the OAuth consent screen.
resource "google_identity_platform_default_supported_idp_config" "google" {
  provider = google-beta
  count    = var.google_oauth_client_id != "" ? 1 : 0

  project       = var.gcp_project_id
  enabled       = true
  idp_id        = "google.com"
  client_id     = var.google_oauth_client_id
  client_secret = var.google_oauth_client_secret

  depends_on = [google_identity_platform_config.auth]
}

# --- Firebase web app (frontend SDK config) -----------------------------------

resource "google_firebase_project" "this" {
  provider = google-beta
  project  = var.gcp_project_id

  depends_on = [google_project_service.firebase]
}

resource "google_firebase_web_app" "customer" {
  provider     = google-beta
  project      = var.gcp_project_id
  display_name = "utro-customer"

  depends_on = [google_firebase_project.this]
}

# Non-secret client config consumed by the customer-ui build (apiKey, authDomain,
# appId, messagingSenderId). Safe to expose — Firebase web config is public.
data "google_firebase_web_app_config" "customer" {
  provider   = google-beta
  project    = var.gcp_project_id
  web_app_id = google_firebase_web_app.customer.app_id
}

# --- Gateway service account (token verification) -----------------------------

# The customer-gateway verifies ID tokens with the Admin SDK. Plain verification
# only needs Google's public certs, but revocation checks (checkRevoked) call
# GetUser, so the SA needs read access to Identity Platform users. firebaseauth
# viewer is the least-privilege role that grants firebaseauth.users.get.
resource "google_service_account" "firebase_admin" {
  project      = var.gcp_project_id
  account_id   = "utro-customer-gw-fb"
  display_name = "utro customer-gateway Firebase token verifier"
}

resource "google_project_iam_member" "firebase_admin_viewer" {
  project = var.gcp_project_id
  role    = "roles/firebaseauth.viewer"
  member  = "serviceAccount:${google_service_account.firebase_admin.email}"
}

resource "google_service_account_key" "firebase_admin" {
  service_account_id = google_service_account.firebase_admin.name
}

# Stored in Secret Manager and surfaced into the cluster via an ExternalSecret
# (see the customer-gateway deployment). Mirrors the gcp-secrets.tf pattern.
resource "google_secret_manager_secret" "firebase_admin_credentials" {
  project   = var.gcp_project_id
  secret_id = "utro-customer-gateway-firebase-admin"

  replication {
    auto {}
  }

  labels = var.tags
}

resource "google_secret_manager_secret_version" "firebase_admin_credentials" {
  secret      = google_secret_manager_secret.firebase_admin_credentials.id
  secret_data = base64decode(google_service_account_key.firebase_admin.private_key)
}

# --- Outputs ------------------------------------------------------------------

output "firebase_web_config" {
  description = "Public Firebase web SDK config for the customer-ui build."
  value = {
    project_id          = google_firebase_web_app.customer.project
    app_id              = google_firebase_web_app.customer.app_id
    api_key             = data.google_firebase_web_app_config.customer.api_key
    auth_domain         = data.google_firebase_web_app_config.customer.auth_domain
    messaging_sender_id = try(data.google_firebase_web_app_config.customer.messaging_sender_id, null)
  }
}

output "firebase_admin_secret_id" {
  description = "Secret Manager secret holding the gateway's Firebase Admin SA key."
  value       = google_secret_manager_secret.firebase_admin_credentials.secret_id
}
