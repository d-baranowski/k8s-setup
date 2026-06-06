#!/usr/bin/env bash
set -euo pipefail

# Creates a scoped Cloudflare API token for Terraform via the REST API.
# No web UI forms needed — just your Global API Key.
#
# Permission IDs are hardcoded from the Cloudflare API.
# If Cloudflare changes IDs, re-discover with: ./list-permission-groups.sh

API="https://api.cloudflare.com/client/v4"

# --- Collect credentials interactively ---

echo "=== Cloudflare API Token Bootstrap ==="
echo ""
echo "You need three things from the Cloudflare dashboard:"
echo ""
echo "  1. Email:      your Cloudflare login email"
echo "  2. Global Key: Profile > API Tokens > Global API Key > View"
echo "  3. Account ID: any zone's Overview page > right sidebar (bottom)"
echo ""
echo "     Or list accounts after entering email + key below."
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

if [[ -z "${CF_ACCOUNT_ID:-}" ]]; then
  echo ""
  echo "Fetching your accounts..."
  ACCOUNTS=$(curl -sf "$API/accounts?per_page=50" "${AUTH[@]}" 2>/dev/null) || {
    echo "ERROR: Failed to authenticate. Check your email and Global API Key." >&2
    exit 1
  }
  ACCOUNT_COUNT=$(echo "$ACCOUNTS" | jq '.result | length')

  if [[ "$ACCOUNT_COUNT" -eq 1 ]]; then
    CF_ACCOUNT_ID=$(echo "$ACCOUNTS" | jq -r '.result[0].id')
    ACCOUNT_NAME=$(echo "$ACCOUNTS" | jq -r '.result[0].name')
    echo "Found 1 account: $ACCOUNT_NAME ($CF_ACCOUNT_ID)"
  elif [[ "$ACCOUNT_COUNT" -gt 1 ]]; then
    echo "Found $ACCOUNT_COUNT accounts:"
    echo "$ACCOUNTS" | jq -r '.result[] | "  \(.id)  \(.name)"'
    echo ""
    read -rp "Account ID: " CF_ACCOUNT_ID
  else
    echo "ERROR: No accounts found for this email." >&2
    exit 1
  fi
else
  echo "Using CF_ACCOUNT_ID from env: $CF_ACCOUNT_ID"
fi

TOKEN_NAME="${TOKEN_NAME:-terraform-infra}"

# --- Hardcoded permission IDs ---
# Discovered via: ./list-permission-groups.sh
# Re-run that script if Cloudflare changes permission group IDs.

# Zone-scoped permissions
ZONE_PERMS='[
  {"id": "c8fed203ed3043cba015a93ad1616f1f"},
  {"id": "4755a26eedb94da69e1066d98aa820be"},
  {"id": "3030687196b94b638145a3953da2b699"},
  {"id": "43137f8d07884d3198dc0ee77ca6e79b"}
]'
# c8fed203 = Zone Read
# 4755a26e = DNS Write
# 30306871 = Zone Settings Write
# 43137f8d = Firewall Services Write

# Account-scoped permissions
ACCOUNT_PERMS='[
  {"id": "c07321b023e944ff818fec44d8203567"},
  {"id": "959972745952452f8be2452be8cbb9f2"},
  {"id": "56907406c3d548ed902070ec4df0e328"}
]'
# c07321b0 = Cloudflare Tunnel Write
# 95997274 = Access: Apps and Policies Write (zone-scoped)
# 56907406 = Account Rulesets Write

echo ""
echo "Permissions:"
echo "  Zone:    Zone Read, DNS Write, Zone Settings Write, Firewall Services Write"
echo "  Account: Cloudflare Tunnel Write, Access: Apps and Policies Write, Account Rulesets Write"

# --- Build the token payload ---

PAYLOAD=$(jq -n \
  --arg name "$TOKEN_NAME" \
  --arg acct "$CF_ACCOUNT_ID" \
  --argjson zone_perms "$ZONE_PERMS" \
  --argjson account_perms "$ACCOUNT_PERMS" \
  '{
    name: $name,
    policies: [
      {
        effect: "allow",
        permission_groups: $zone_perms,
        resources: {
          ("com.cloudflare.api.account." + $acct): {
            "com.cloudflare.api.account.zone.*": "*"
          }
        }
      },
      {
        effect: "allow",
        permission_groups: $account_perms,
        resources: {
          ("com.cloudflare.api.account." + $acct): "*"
        }
      }
    ]
  }')

echo ""
echo "Creating token '$TOKEN_NAME'..."
RESPONSE=$(curl -sf "$API/user/tokens" "${AUTH[@]}" --data "$PAYLOAD") || {
  echo "ERROR: Token creation request failed." >&2
  exit 1
}

SUCCESS=$(echo "$RESPONSE" | jq -r '.success')
if [[ "$SUCCESS" != "true" ]]; then
  echo "ERROR: Token creation failed:" >&2
  echo "$RESPONSE" | jq . >&2
  exit 1
fi

TOKEN_VALUE=$(echo "$RESPONSE" | jq -r '.result.value')
TOKEN_ID=$(echo "$RESPONSE" | jq -r '.result.id')

echo ""
echo "============================================"
echo "  Token created successfully!"
echo "  ID:    $TOKEN_ID"
echo "  Name:  $TOKEN_NAME"
echo "  Value: $TOKEN_VALUE"
echo "============================================"
echo ""
echo "IMPORTANT: This value is shown ONLY ONCE."
echo ""
echo "Next steps:"
echo "  export CLOUDFLARE_API_TOKEN=\"$TOKEN_VALUE\""
echo "  export TF_VAR_cloudflare_api_token=\"$TOKEN_VALUE\""

echo ""
echo "Verifying token..."
VERIFY=$(curl -sf "$API/user/tokens/verify" -H "Authorization: Bearer $TOKEN_VALUE") || {
  echo "WARNING: Token verification request failed." >&2
  exit 0
}
echo "Status: $(echo "$VERIFY" | jq -r '.result.status')"
