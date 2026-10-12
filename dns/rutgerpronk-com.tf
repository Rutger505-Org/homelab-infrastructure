locals {
  rutgerpronk_com = local.zone_ids.rutgerpronk_com
}

# Home IP, port-forwarded to the k3s ingress. DNS only: traffic goes straight
# to the cluster, which handles TLS itself.
resource "cloudflare_dns_record" "rutgerpronk_com_apex" {
  zone_id = local.rutgerpronk_com
  name    = "rutgerpronk.com"
  type    = "A"
  content = "213.93.151.113"
  ttl     = 1
  proxied = false
}

resource "cloudflare_dns_record" "rutgerpronk_com_wildcard" {
  zone_id = local.rutgerpronk_com
  name    = "*.rutgerpronk.com"
  type    = "CNAME"
  content = "rutgerpronk.com"
  ttl     = 1
  proxied = false
}

# dijker-website VM (Docker Compose + Caddy), not the home IP.
resource "cloudflare_dns_record" "dijker" {
  zone_id = local.rutgerpronk_com
  name    = "dijker.rutgerpronk.com"
  type    = "A"
  content = "217.154.21.228"
  ttl     = 1
  proxied = false
}

resource "cloudflare_dns_record" "dijker_wildcard" {
  zone_id = local.rutgerpronk_com
  name    = "*.dijker.rutgerpronk.com"
  type    = "CNAME"
  content = "dijker.rutgerpronk.com"
  ttl     = 1
  proxied = false
}

resource "cloudflare_dns_record" "rutgerpronk_com_google_verification" {
  zone_id = local.rutgerpronk_com
  name    = "rutgerpronk.com"
  type    = "TXT"
  content = "\"google-site-verification=322MpOaWgRL1IHbCzKMyj4rE-hoJZASxoIS1ZbCfMAc\""
  ttl     = 3600
  proxied = false
}
