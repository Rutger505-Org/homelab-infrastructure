locals {
  rutgerpronk_nl = local.zone_ids.rutgerpronk_nl
}

resource "cloudflare_dns_record" "rutgerpronk_nl_apex" {
  zone_id = local.rutgerpronk_nl
  name    = "rutgerpronk.nl"
  type    = "A"
  content = "213.93.151.113"
  ttl     = 1
  proxied = true
}

# Leftover apex NS records from the TransIP move. The zone is served by
# Cloudflare's own nameservers; these are kept as-is for a 1:1 import.
resource "cloudflare_dns_record" "rutgerpronk_nl_ns" {
  for_each = toset(["ns0.transip.net", "ns1.transip.nl", "ns2.transip.eu"])

  zone_id = local.rutgerpronk_nl
  name    = "rutgerpronk.nl"
  type    = "NS"
  content = each.value
  ttl     = 1
  proxied = false
}
