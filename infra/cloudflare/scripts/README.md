# Cloudflare Scripts

## create-api-token.sh

Creates a scoped Cloudflare API token for Terraform via the REST API — no web UI forms needed.

### Prerequisites

- `jq` and `curl` installed
- Your Cloudflare **login email** and **Global API Key**

### Finding your Global API Key

In the Cloudflare dashboard: **Profile > API Tokens > Global API Key > View** (just a copy button).

### Finding your Account ID

The script auto-detects your account if you only have one. If you have multiple accounts, it lists them and asks you to pick.

You can also find it manually: open any domain in the dashboard, the Account ID is in the right sidebar at the bottom of the Overview page.

### Usage

Run the script interactively — it prompts for everything:

```bash
./scripts/create-api-token.sh
```

Or pass credentials via env vars to skip prompts:

```bash
export CF_EMAIL="you@example.com"
export CF_API_KEY="your-global-api-key"
export CF_ACCOUNT_ID="your-account-id"  # optional, auto-detected if single account
./scripts/create-api-token.sh
```

The script will:

1. Authenticate with your Global API Key
2. Auto-detect your account (or list accounts to choose from)
3. Fetch all available permission groups from the Cloudflare API
4. Match the required permissions by pattern (Zone Read, DNS Write, Zone Settings Write, Firewall Services Write, Tunnel Write, Access Apps & Policies, Account Rulesets Write)
5. Create a scoped token named `terraform-infra` (override with `TOKEN_NAME` env var)
6. Verify the token works

**The token value is shown only once** — save it immediately.

### After creating the token

```bash
export CLOUDFLARE_API_TOKEN="the-token-value"
echo 'cloudflare_account_id = "your-account-id"' > terraform.tfvars
terraform plan
```

### Troubleshooting

If a permission group can't be matched, the script dumps all available groups to `/tmp/cf-permission-groups.json` for review. The patterns in the `WANTED` array at the top of the script can be adjusted if Cloudflare renames permission groups.
