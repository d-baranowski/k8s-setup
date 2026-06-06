#!/usr/bin/env bash
set -euo pipefail

API="https://api.cloudflare.com/client/v4"

echo "=== Cloudflare Permission Groups Discovery ==="
echo ""
echo "This script lists all available permission groups so you can"
echo "pick the exact IDs for create-api-token.sh."
echo ""

if [[ -n "${CF_EMAIL:-}" ]]; then
  echo "Using CF_EMAIL from env: $CF_EMAIL"
else
  read -rp "Cloudflare email: " CF_EMAIL
fi

if [[ -n "${CF_API_KEY:-}" ]]; then
  echo "Using CF_API_KEY from env: (set)"
else
  read -rsp "Global API Key: " CF_API_KEY
  echo ""
fi

AUTH=(-H "X-Auth-Email: $CF_EMAIL" -H "X-Auth-Key: $CF_API_KEY" -H "Content-Type: application/json")

echo ""
echo "Fetching permission groups..."
PERMS=$(curl -sf "$API/user/tokens/permission_groups?per_page=500" "${AUTH[@]}") || {
  echo "ERROR: Failed to authenticate. Check your email and Global API Key." >&2
  exit 1
}

FILTER="${1:-}"

if [[ -n "$FILTER" ]]; then
  echo ""
  echo "Filtering for: $FILTER"
  echo ""
  echo "$PERMS" | jq -r --arg f "$FILTER" '
    .result
    | map(select(.name | test($f; "i")))
    | sort_by(.name)
    | .[]
    | "\(.id)  \(.scopes | join(","))  \(.name)"'
else
  echo ""
  echo "All permission groups (pass a filter arg to narrow, e.g.: ./list-permission-groups.sh access)"
  echo ""
  echo "$PERMS" | jq -r '
    .result
    | sort_by(.name)
    | .[]
    | "\(.id)  \(.scopes | join(","))  \(.name)"'
fi
