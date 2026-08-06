#!/usr/bin/env bash
#
# Store the Google OAuth web-client credentials (for customer Google sign-in) in
# GCP Secret Manager, so they live there instead of in terraform.tfvars.
#
# Run ONCE. Re-running just adds a new version (safe). Terraform then reads these
# via data.google_secret_manager_secret_version in firebase.tf, gated on
# enable_google_signin = true.
#
# Values come from the "Utro Client" OAuth 2.0 Web application client:
#   GCP Console -> APIs & Services -> Credentials -> Utro Client
#
# Usage:
#   ./put-google-oauth-secrets.sh              # prompts for both values
#   GCP_PROJECT=danb-ubuntu-k0s ./put-google-oauth-secrets.sh
set -euo pipefail

PROJECT="${GCP_PROJECT:-danb-ubuntu-k0s}"
ID_SECRET="utro-customer-google-oauth-client-id"
SECRET_SECRET="utro-customer-google-oauth-client-secret"

# Prompt without echoing the secret to the terminal / shell history.
read -rp  "Google OAuth Web client ID:     " CLIENT_ID
read -rsp "Google OAuth Web client secret: " CLIENT_SECRET
echo

if [[ -z "${CLIENT_ID}" || -z "${CLIENT_SECRET}" ]]; then
  echo "error: both the client ID and secret are required" >&2
  exit 1
fi

put_secret() {
  local name="$1" value="$2"
  if ! gcloud secrets describe "${name}" --project="${PROJECT}" >/dev/null 2>&1; then
    echo "creating secret ${name}"
    gcloud secrets create "${name}" \
      --project="${PROJECT}" \
      --replication-policy="automatic" \
      --labels="application=utro,managed-by=script" >/dev/null
  fi
  printf '%s' "${value}" | gcloud secrets versions add "${name}" \
    --project="${PROJECT}" --data-file=- >/dev/null
  echo "stored new version of ${name}"
}

put_secret "${ID_SECRET}"     "${CLIENT_ID}"
put_secret "${SECRET_SECRET}" "${CLIENT_SECRET}"

cat <<EOF

Done. Both secrets are in Secret Manager (project ${PROJECT}).

Next:
  1. set  enable_google_signin = true  in terraform.tfvars
  2. terraform apply   (reads the secrets and enables the Google IdP)

Whoever runs terraform needs roles/secretmanager.secretAccessor on these secrets.
EOF
