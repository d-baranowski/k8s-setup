#!/usr/bin/env bash
set -euo pipefail

# Creates a scoped Cloudflare API token for Terraform via the REST API.
# No web UI forms needed — just your Global API Key.

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

# --- Fetch permission groups and match by pattern ---

echo ""
echo "Fetching permission groups..."
PERMS=$(curl -sf "$API/user/tokens/permission_groups?per_page=500" "${AUTH[@]}") || {
  echo "ERROR: Failed to fetch permission groups." >&2
  exit 1
}

# Match permissions by pattern — names are cosmetic and may change,
# so we search by keyword rather than hardcoding exact strings.
# Each entry: "search_pattern|scope|label"
WANTED=(
  "Zone Read|zone|Zone Read"
  "DNS Write|zone|DNS Write"
  "Zone Settings Write|zone|Zone Settings Write"
  "Firewall Services Write|zone|Firewall Services Write"
  "Tunnel Write|account|Tunnel Write"
  "Access.*Apps.*Policies|account|Access: Apps & Policies"
  "Account Rulesets Write|account|Account Rulesets Write"
)

ZONE_IDS_JSON="[]"
ACCOUNT_IDS_JSON="[]"
ERRORS=0

for entry in "${WANTED[@]}"; do
  IFS='|' read -r pattern scope label <<< "$entry"

  id=$(echo "$PERMS" | jq -r --arg p "$pattern" \
    '[.result[] | select(.name | test($p; "i"))] | sort_by(.name) | first | .id // empty')
  name=$(echo "$PERMS" | jq -r --arg p "$pattern" \
    '[.result[] | select(.name | test($p; "i"))] | sort_by(.name) | first | .name // empty')

  if [[ -z "$id" ]]; then
    echo "  MISS: no match for pattern '$pattern'" >&2
    echo "        Candidates:" >&2
    echo "$PERMS" | jq -r --arg p "${pattern%%[. ]*}" \
      '[.result[] | select(.name | test($p; "i"))] | .[] | "          \(.id)  \(.name)"' >&2
    ERRORS=$((ERRORS + 1))
  else
    echo "  OK:   $name ($id)"
    if [[ "$scope" == "zone" ]]; then
      ZONE_IDS_JSON=$(echo "$ZONE_IDS_JSON" | jq --arg id "$id" '. + [{"id": $id}]')
    else
      ACCOUNT_IDS_JSON=$(echo "$ACCOUNT_IDS_JSON" | jq --arg id "$id" '. + [{"id": $id}]')
    fi
  fi
done

if [[ $ERRORS -gt 0 ]]; then
  echo ""
  echo "ERROR: $ERRORS permission(s) could not be resolved." >&2
  echo "Dumping all available permission groups to: /tmp/cf-permission-groups.json" >&2
  echo "$PERMS" | jq '.result | sort_by(.name) | .[] | {id, name, scopes}' > /tmp/cf-permission-groups.json
  echo "Review that file and update the WANTED patterns in this script." >&2
  exit 1
fi

# --- Build the token payload ---

PAYLOAD=$(jq -n \
  --arg name "$TOKEN_NAME" \
  --arg acct "$CF_ACCOUNT_ID" \
  --argjson zone_perms "$ZONE_IDS_JSON" \
  --argjson account_perms "$ACCOUNT_IDS_JSON" \
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
echo "  echo 'cloudflare_account_id = \"$CF_ACCOUNT_ID\"' > terraform.tfvars"

echo ""
echo "Verifying token..."
VERIFY=$(curl -sf "$API/user/tokens/verify" -H "Authorization: Bearer $TOKEN_VALUE") || {
  echo "WARNING: Token verification request failed." >&2
  exit 0
}
echo "Status: $(echo "$VERIFY" | jq -r '.result.status')"
