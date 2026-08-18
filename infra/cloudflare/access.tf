# Webhook bypass — allows Resend to POST delivery status webhooks
# without Cloudflare Access authentication. The Svix signature
# verification in the notification service ensures only legitimate
# payloads are processed.

resource "cloudflare_zero_trust_access_application" "staging_webhook" {
  zone_id          = local.zone_inspi_cloud
  name             = "Staging Webhook Bypass"
  domain           = "utro-test.inspi.cloud/webhook"
  type             = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_zero_trust_access_policy" "staging_webhook_bypass" {
  zone_id        = local.zone_inspi_cloud
  application_id = cloudflare_zero_trust_access_application.staging_webhook.id
  name           = "Bypass for webhooks"
  decision       = "bypass"
  precedence     = 1

  include {
    everyone = true
  }
}

resource "cloudflare_zero_trust_access_application" "production_webhook" {
  zone_id          = local.zone_inspiration_particle
  name             = "Production Webhook Bypass"
  domain           = "utro.inspiration-particle.com/webhook"
  type             = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_zero_trust_access_policy" "production_webhook_bypass" {
  zone_id        = local.zone_inspiration_particle
  application_id = cloudflare_zero_trust_access_application.production_webhook.id
  name           = "Bypass for webhooks"
  decision       = "bypass"
  precedence     = 1

  include {
    everyone = true
  }
}

# The customer app and its API are public (customers are not org members). Bypass
# Cloudflare Access; auth is enforced by Firebase + the customer-gateway, not Access.
resource "cloudflare_zero_trust_access_application" "customer_app" {
  zone_id          = local.zone_inspiration_particle
  name             = "Customer App Bypass"
  domain           = "app.inspiration-particle.com"
  type             = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_zero_trust_access_policy" "customer_app_bypass" {
  zone_id        = local.zone_inspiration_particle
  application_id = cloudflare_zero_trust_access_application.customer_app.id
  name           = "Bypass for customers"
  decision       = "bypass"
  precedence     = 2

  include {
    everyone = true
  }
}

resource "cloudflare_zero_trust_access_application" "customer_api" {
  zone_id          = local.zone_inspiration_particle
  name             = "Customer API Bypass"
  domain           = "customer-api.inspiration-particle.com"
  type             = "self_hosted"
  session_duration = "24h"
}

# Contact form is public (called from kadis.inspi.cloud). Access would break CORS.
resource "cloudflare_zero_trust_access_application" "kadis_api" {
  zone_id          = local.zone_inspi_cloud
  name             = "Kadis contact API bypass"
  domain           = "kadis-api.inspi.cloud"
  type             = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_zero_trust_access_policy" "kadis_api_bypass" {
  zone_id        = local.zone_inspi_cloud
  application_id = cloudflare_zero_trust_access_application.kadis_api.id
  name           = "Bypass for contact form"
  decision       = "bypass"
  precedence     = 1

  include {
    everyone = true
  }
}

resource "cloudflare_zero_trust_access_policy" "customer_api_bypass" {
  zone_id        = local.zone_inspiration_particle
  application_id = cloudflare_zero_trust_access_application.customer_api.id
  name           = "Bypass for customers"
  decision       = "bypass"
  precedence     = 3

  include {
    everyone = true
  }
}
