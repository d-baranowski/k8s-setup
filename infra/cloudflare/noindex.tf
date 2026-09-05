# Keep the staging customer app out of search results.
#
# Applied at the edge rather than in the app: customer-ui ships one bundle per
# environment already, but a robots meta tag would have to be a build-time flag
# too, and this way the guarantee is a property of the hostname rather than of
# whichever image happens to be deployed. It also covers the API host, which
# serves no HTML to put a meta tag in.
#
# The zone has one ruleset per phase. If a Transform Rule already exists on
# inspi.cloud from the dashboard, this will adopt and overwrite it — check
# before the first apply.
#
# Needs Zone > Transform Rules (Edit) on the API token, which is a different
# grant from the Account Rulesets one noted in providers.tf.
resource "cloudflare_ruleset" "inspi_cloud_response_headers" {
  zone_id = local.zone_inspi_cloud
  name    = "Response header transforms"
  kind    = "zone"
  phase   = "http_response_headers_transform"

  rules {
    action      = "rewrite"
    description = "noindex the staging customer app and API"
    enabled     = true
    expression  = "(http.host in {\"customer.inspi.cloud\" \"customer-api.inspi.cloud\"})"

    action_parameters {
      headers {
        name      = "X-Robots-Tag"
        operation = "set"
        value     = "noindex, nofollow"
      }
    }
  }
}
