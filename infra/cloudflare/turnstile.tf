# Cloudflare Turnstile widget for the staging customer registration form.
#
# The customer-gateway runs with CAPTCHA_ENABLED=true and calls siteverify with
# the secret half; the customer-ui renders the widget with the site key half,
# which is baked into its bundle at build time. Both halves must come from the
# same widget or every submission is rejected.
#
# Staging keeps the CAPTCHA on rather than disabling it: customer.inspi.cloud is
# genuinely public, and a staging that skips this is not exercising the path
# production runs.
resource "cloudflare_turnstile_widget" "staging_customer" {
  account_id = local.account_id
  name       = "utro staging customer registration"
  domains    = ["customer.inspi.cloud"]
  # Managed renders a checkbox only when Cloudflare's own signals are
  # inconclusive, which is the least intrusive option that still yields a token
  # the gateway can verify on every submission.
  mode   = "managed"
  region = "world"
}

output "staging_customer_turnstile_site_key" {
  description = <<-EOT
    Public site key for the staging customer registration widget.

    Set this as TURNSTILE_SITE_KEY_STAGING in the Jenkins environment — the
    customer-ui-staging image inlines it at build time, so it takes a rebuild to
    change, not a redeploy.
  EOT
  value       = cloudflare_turnstile_widget.staging_customer.id
}

output "staging_customer_turnstile_secret" {
  description = <<-EOT
    Server-side secret for the staging customer registration widget.

    Push into Google Secret Manager under `utro-customer-turnstile-staging-secret`,
    where the utr-staging-turnstile ExternalSecret reads it from:

      terraform output -raw staging_customer_turnstile_secret \
        | gcloud secrets versions add utro-customer-turnstile-staging-secret \
            --project danb-ubuntu-k0s --data-file=-
  EOT
  value       = cloudflare_turnstile_widget.staging_customer.secret
  sensitive   = true
}
