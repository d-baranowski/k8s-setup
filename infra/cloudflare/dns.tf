# ── inspi.cloud ──────────────────────────────────────────────

resource "cloudflare_record" "staging_utro_test" {
  zone_id = local.zone_inspi_cloud
  name    = "utro-test"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.utro.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
  ttl     = 1
}

# ── inspiration-particle.com ────────────────────────────────

resource "cloudflare_record" "root_a" {
  zone_id = local.zone_inspiration_particle
  name    = "inspiration-particle.com"
  content = "76.76.21.21"
  type    = "A"
  proxied = true
  ttl     = 1
}

resource "cloudflare_record" "jenkins_cname" {
  zone_id = local.zone_inspiration_particle
  name    = "jenkins"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.jenkins.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
  ttl     = 1
}

resource "cloudflare_record" "local_debug_cname" {
  zone_id = local.zone_inspiration_particle
  name    = "local-debug"
  content = "1c1406db-c974-4c2d-b5ac-96b59e019e5e.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
  ttl     = 1
}

resource "cloudflare_record" "utro_cname" {
  zone_id = local.zone_inspiration_particle
  name    = "utro"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.utro.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
  ttl     = 1
}

resource "cloudflare_record" "www_cname" {
  zone_id = local.zone_inspiration_particle
  name    = "www"
  content = "cname.vercel-dns.com"
  type    = "CNAME"
  proxied = true
  ttl     = 1
}

resource "cloudflare_record" "mx_privateemail_2" {
  zone_id  = local.zone_inspiration_particle
  name     = "inspiration-particle.com"
  content  = "mx2.privateemail.com"
  type     = "MX"
  priority = 10
  proxied  = false
  ttl      = 1
}

resource "cloudflare_record" "mx_privateemail_1" {
  zone_id  = local.zone_inspiration_particle
  name     = "inspiration-particle.com"
  content  = "mx1.privateemail.com"
  type     = "MX"
  priority = 10
  proxied  = false
  ttl      = 1
}

resource "cloudflare_record" "mx_send_ses" {
  zone_id  = local.zone_inspiration_particle
  name     = "send"
  content  = "feedback-smtp.eu-west-1.amazonses.com"
  type     = "MX"
  priority = 10
  proxied  = false
  ttl      = 3600
}

resource "cloudflare_record" "ns_registrar_2" {
  zone_id = local.zone_inspiration_particle
  name    = "inspiration-particle.com"
  content = "dns2.registrar-servers.com"
  type    = "NS"
  proxied = false
  ttl     = 1
}

resource "cloudflare_record" "ns_registrar_1" {
  zone_id = local.zone_inspiration_particle
  name    = "inspiration-particle.com"
  content = "dns1.registrar-servers.com"
  type    = "NS"
  proxied = false
  ttl     = 1
}

resource "cloudflare_record" "txt_spf" {
  zone_id = local.zone_inspiration_particle
  name    = "inspiration-particle.com"
  content = "\"v=spf1 include:spf.privateemail.com ~all\""
  type    = "TXT"
  proxied = false
  ttl     = 1
}

resource "cloudflare_record" "txt_resend_dkim" {
  zone_id = local.zone_inspiration_particle
  name    = "resend._domainkey"
  content = "\"p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCjzS7Iq9W7rfVL/HG1YmJK0FklhfRtcUhXI+yTlxYG0tdI5IoP1AItfwAKFrSU/RzU80NxlNeHmoU+lNLApxpvUM68leUyp4qkOdq0N+AfOBbg+kuHDuTP9hAEgpij5FLv0IUA9KfVlzVS3P17l0OuJ9SAKnlJmxVjitjEieGlOQIDAQAB\""
  type    = "TXT"
  proxied = false
  ttl     = 3600
}

resource "cloudflare_record" "txt_send_spf" {
  zone_id = local.zone_inspiration_particle
  name    = "send"
  content = "\"v=spf1 include:amazonses.com ~all\""
  type    = "TXT"
  proxied = false
  ttl     = 3600
}
