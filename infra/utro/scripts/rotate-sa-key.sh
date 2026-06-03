#!/usr/bin/env bash
# rotate-sa-key.sh — mint a fresh JSON key for a service account managed
# by the sibling Terraform stack and mirror it to its consumers.
#
# What Terraform owns vs what this script owns:
#   - Terraform (../ci-fleet.tf) creates the SA, custom role, role
#     binding. SA *keys* are deliberately NOT in Terraform state — the
#     bytes shouldn't live in the .tfstate file alongside everything
#     else and they need to be rotatable independently.
#   - This script: mints a new key, ages out the oldest if at GCP's
#     10-key cap, drops it into the Jenkins credential / sops file
#     that consume it.
#
# Two SAs to rotate (pass --sa to pick):
#   ci-fleet                 → consumed by the GCE Jenkins plugin
#                              (Jenkins credential id: gcp-ci-fleet-sa-key)
#   utro-firewall-updater    → consumed by may-chang's
#                              gcp-firewall-updater systemd timer
#                              (sops key: gcp_firewall_updater_sa_key_base64
#                               in nixos-workbenches/nixos-servers/secrets/may-chang.yaml)
#
# Usage:
#   ./rotate-sa-key.sh --sa ci-fleet
#   ./rotate-sa-key.sh --sa utro-firewall-updater
#
# Run from any cwd; paths inside are absolute / relative to script dir.

set -euo pipefail

PROJECT="${PROJECT:-danb-ubuntu-k0s}"
SOPS_FILE="${SOPS_FILE:-$HOME/Workspace/nixos-workbenches/nixos-servers/secrets/may-chang.yaml}"

log() { printf '\033[1;34m[rotate-sa-key]\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m[rotate-sa-key]\033[0m %s\n' "$*" >&2; exit 1; }

require_gcloud() {
  command -v gcloud >/dev/null \
    || die "gcloud not on PATH"
  local active
  active=$(gcloud auth list --filter=status:ACTIVE --format='value(account)')
  [[ -n "$active" ]] || die "gcloud not authenticated — run: gcloud auth login"
  [[ "$active" == *"iam.gserviceaccount.com"* ]] \
    && die "active gcloud account is a service account ($active). Switch back to a user account."
}

usage() {
  cat >&2 <<EOF
usage: $0 --sa <ci-fleet|utro-firewall-updater>

Mints a new JSON key for the named service account and routes it to
its consumer (Jenkins credential or sops file). See header for details.

Optional env:
  PROJECT     (default: $PROJECT)
  SOPS_FILE   (default: $SOPS_FILE)
EOF
  exit 2
}

[[ "${1:-}" == "--sa" && -n "${2:-}" ]] || usage
SA_SHORT="$2"
SA_EMAIL="${SA_SHORT}@${PROJECT}.iam.gserviceaccount.com"
KEY_OUT=$(mktemp)
trap 'shred -u "$KEY_OUT" 2>/dev/null || rm -P "$KEY_OUT" 2>/dev/null || rm -f "$KEY_OUT"' EXIT

require_gcloud

# Verify the SA exists (must have been created by Terraform first).
gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT" >/dev/null \
  || die "SA $SA_EMAIL doesn't exist. Apply ../ci-fleet.tf first."

# GCP caps user-managed keys at 10 per SA. Prune oldest if at cap.
existing=$(gcloud iam service-accounts keys list \
  --iam-account="$SA_EMAIL" --managed-by=user \
  --format='value(name)' | wc -l | tr -d ' ')
if [[ "$existing" -ge 10 ]]; then
  log "SA at 10-key cap — pruning oldest user-managed key"
  oldest=$(gcloud iam service-accounts keys list \
    --iam-account="$SA_EMAIL" --managed-by=user \
    --sort-by=validAfterTime --format='value(name)' | head -1)
  gcloud iam service-accounts keys delete "$oldest" \
    --iam-account="$SA_EMAIL" --quiet
fi

log "minting new key for $SA_EMAIL"
gcloud iam service-accounts keys create "$KEY_OUT" --iam-account="$SA_EMAIL" >/dev/null
chmod 0400 "$KEY_OUT"

# Route the key to its consumer.
case "$SA_SHORT" in
  ci-fleet)
    log "installing into Jenkins as credential 'gcp-ci-fleet-sa-key'"
    "$(cd "$(dirname "$0")" && pwd)/install-gcp-ci-fleet-credential.sh" "$KEY_OUT"
    # The trap on EXIT shreds $KEY_OUT.
    ;;

  utro-firewall-updater)
    [[ -f "$SOPS_FILE" ]] || die "SOPS_FILE not found: $SOPS_FILE"
    log "base64-encoding new key + writing to sops at gcp_firewall_updater_sa_key_base64"
    KEY_B64=$(base64 -i "$KEY_OUT" | tr -d '\n')
    SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt" \
      sops --set "[\"gcp_firewall_updater_sa_key_base64\"] \"$KEY_B64\"" "$SOPS_FILE"
    log "✓ sops updated. Now redeploy may-chang to pick up the new key:"
    cat <<'EOF'
  cd ~/Workspace/nixos-workbenches/nixos-servers
  nix run nixpkgs#nixos-rebuild -- switch --flake .#may-chang \
    --target-host dan@may-chang.folk-saiph.ts.net --sudo \
    --build-host  dan@may-chang.folk-saiph.ts.net --sudo \
    --ask-sudo-password
EOF
    ;;

  *)
    die "unknown SA '$SA_SHORT' — supported: ci-fleet, utro-firewall-updater"
    ;;
esac

log "✓ rotation complete for $SA_EMAIL"
