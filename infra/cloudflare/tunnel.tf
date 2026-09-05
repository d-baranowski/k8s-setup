resource "cloudflare_zero_trust_tunnel_cloudflared" "utro" {
  account_id = local.account_id
  name       = "utro"
  secret     = "placeholder"

  lifecycle {
    ignore_changes = [secret]
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "utro" {
  account_id = local.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.utro.id

  config {
    ingress_rule {
      hostname = "utro.inspiration-particle.com"
      path     = "/webhook"
      service  = "http://utro-gateway.default.svc.cluster.local:9999"
      origin_request {
        connect_timeout        = "30s"
        keep_alive_connections = 100
        keep_alive_timeout     = "1m30s"
        proxy_address          = "127.0.0.1"
        tcp_keep_alive         = "30s"
        tls_timeout            = "10s"
      }
    }
    ingress_rule {
      hostname = "utro-test.inspi.cloud"
      path     = "/webhook"
      service  = "http://utr-staging-gateway.default.svc.cluster.local:9999"
      origin_request {
        connect_timeout        = "30s"
        keep_alive_connections = 100
        keep_alive_timeout     = "1m30s"
        proxy_address          = "127.0.0.1"
        tcp_keep_alive         = "30s"
        tls_timeout            = "10s"
      }
    }
    ingress_rule {
      hostname = "utro.inspiration-particle.com"
      service  = "http://utro-ui.default.svc.cluster.local:3000"
      origin_request {
        connect_timeout        = "30s"
        keep_alive_connections = 100
        keep_alive_timeout     = "1m30s"
        proxy_address          = "127.0.0.1"
        tcp_keep_alive         = "30s"
        tls_timeout            = "10s"
      }
    }
    ingress_rule {
      hostname = "utro-test.inspi.cloud"
      service  = "http://utr-staging-ui.default.svc.cluster.local:3000"
      origin_request {
        connect_timeout        = "30s"
        keep_alive_connections = 100
        keep_alive_timeout     = "1m30s"
        proxy_address          = "127.0.0.1"
        tcp_keep_alive         = "30s"
        tls_timeout            = "10s"
      }
    }
    # Customer app API (Connect/gRPC). Public — Firebase Bearer tokens are verified by
    # the customer-gateway itself; Cloudflare Access is bypassed for this host (access.tf).
    ingress_rule {
      hostname = "customer-api.inspiration-particle.com"
      service  = "http://utro-customer-gateway.default.svc.cluster.local:9998"
      origin_request {
        connect_timeout        = "30s"
        keep_alive_connections = 100
        keep_alive_timeout     = "1m30s"
        proxy_address          = "127.0.0.1"
        tcp_keep_alive         = "30s"
        tls_timeout            = "10s"
      }
    }
    ingress_rule {
      hostname = "kadis-api.inspi.cloud"
      service  = "http://kadis-contact.kadis.svc.cluster.local:8080"
      origin_request {
        connect_timeout        = "30s"
        keep_alive_connections = 100
        keep_alive_timeout     = "1m30s"
        proxy_address          = "127.0.0.1"
        tcp_keep_alive         = "30s"
        tls_timeout            = "10s"
      }
    }
    # Customer web/mobile app.
    ingress_rule {
      hostname = "app.inspiration-particle.com"
      service  = "http://utro-customer-ui.default.svc.cluster.local:3000"
      origin_request {
        connect_timeout        = "30s"
        keep_alive_connections = 100
        keep_alive_timeout     = "1m30s"
        proxy_address          = "127.0.0.1"
        tcp_keep_alive         = "30s"
        tls_timeout            = "10s"
      }
    }
    # Staging customer app + its API. Public, like their production
    # counterparts: Cloudflare Access is bypassed for both hosts (access.tf)
    # and auth is Firebase + the customer-gateway, not Access.
    ingress_rule {
      hostname = "customer-api.inspi.cloud"
      service  = "http://utr-staging-customer-gateway.default.svc.cluster.local:9998"
      origin_request {
        connect_timeout        = "30s"
        keep_alive_connections = 100
        keep_alive_timeout     = "1m30s"
        proxy_address          = "127.0.0.1"
        tcp_keep_alive         = "30s"
        tls_timeout            = "10s"
      }
    }
    ingress_rule {
      hostname = "customer.inspi.cloud"
      service  = "http://utr-staging-customer-ui.default.svc.cluster.local:3000"
      origin_request {
        connect_timeout        = "30s"
        keep_alive_connections = 100
        keep_alive_timeout     = "1m30s"
        proxy_address          = "127.0.0.1"
        tcp_keep_alive         = "30s"
        tls_timeout            = "10s"
      }
    }
    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "jenkins" {
  account_id = local.account_id
  name       = "jenkins"
  secret     = "placeholder"

  lifecycle {
    ignore_changes = [secret]
  }
}
