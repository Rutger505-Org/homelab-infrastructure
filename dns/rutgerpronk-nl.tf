locals {
  rutgerpronk_nl = local.zone_ids.rutgerpronk_nl
}

# rutgerpronk.nl only exists to redirect to rutgerpronk.com. Both records are
# proxied so Cloudflare answers and the redirect rule below runs; the origin
# IP is never reached.
resource "cloudflare_dns_record" "rutgerpronk_nl_apex" {
  zone_id = local.rutgerpronk_nl
  name    = "rutgerpronk.nl"
  type    = "A"
  content = "213.93.151.113"
  ttl     = 1
  proxied = true
}

resource "cloudflare_dns_record" "rutgerpronk_nl_wildcard" {
  zone_id = local.rutgerpronk_nl
  name    = "*.rutgerpronk.nl"
  type    = "A"
  content = "213.93.151.113"
  ttl     = 1
  proxied = true
}

# Keeps subdomain, path and query: dijker.rutgerpronk.nl/foo?a=1 goes to
# https://dijker.rutgerpronk.com/foo?a=1.
resource "cloudflare_ruleset" "rutgerpronk_nl_redirect" {
  zone_id = local.rutgerpronk_nl
  name    = "default"
  kind    = "zone"
  phase   = "http_request_dynamic_redirect"

  rules = [{
    ref         = "nl_to_com"
    description = "Redirect rutgerpronk.nl and its subdomains to rutgerpronk.com"
    expression  = "(http.host wildcard \"rutgerpronk.nl\" or http.host wildcard \"*.rutgerpronk.nl\")"
    action      = "redirect"

    action_parameters = {
      from_value = {
        status_code           = 301
        preserve_query_string = false
        target_url = {
          expression = "wildcard_replace(http.request.full_uri, \"*://*rutgerpronk.nl/*\", \"https://$${2}rutgerpronk.com/$${3}\")"
        }
      }
    }
  }]
}
