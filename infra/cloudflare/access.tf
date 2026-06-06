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
