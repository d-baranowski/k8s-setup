variable "cloudflare_api_token" {
  description = "Cloudflare API token with permissions to manage zones, DNS, tunnels, zero trust, and WAF"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID (found at the bottom of any zone's Overview page)"
  type        = string
}
