# Cloudflare provider configuration
# Set this environment variable before running Terraform:
#   export CLOUDFLARE_API_TOKEN="your-api-token"
#
# Create a scoped API token at https://dash.cloudflare.com/profile/api-tokens
# Required permissions: Zone (Read), DNS (Edit), Zone Settings (Edit),
# Firewall Services (Edit), Cloudflare Tunnel (Edit), Access (Edit),
# Account Rulesets (Edit).
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
