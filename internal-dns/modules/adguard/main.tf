terraform {
  required_providers {
    adguard = {
      source = "gmichels/adguard"
    }
  }
}

variable "domain" {
  description = "Internal domain, rewritten with its subdomains to the reverse proxy"
  type        = string
}

variable "reverse_proxy" {
  description = "Reverse proxy address the rewrites answer with"
  type        = string
}

# The bare domain, for the landing page linking every service.
resource "adguard_rewrite" "apex" {
  domain = var.domain
  answer = var.reverse_proxy
}

resource "adguard_rewrite" "wildcard" {
  domain = "*.${var.domain}"
  answer = var.reverse_proxy
}

# Blocks the encrypted DNS (DoH) endpoints browsers and apps use to go around
# AdGuard Home, which would also skip the rewrites above. Only the client
# queries are filtered: AdGuard Home's own DoH upstreams resolve through the
# bootstrap servers.
resource "adguard_list_filter" "encrypted_dns_bypass" {
  name = "HaGeZi Encrypted DNS Bypass"
  url  = "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists/adblock/doh.txt"
}

# Owns ALL custom filtering rules: rules added in the web UI are drift and
# get reverted. Allowlist entries undo blocks by the default AdGuard DNS
# filter (still managed in the web UI) where they break things.
resource "adguard_user_rules" "this" {
  rules = [
    "! Gamma newsletter buttons: Adobe click tracker, breaks every link in their mails",
    "@@||data.email.gamma.nl^",
  ]
}

output "records" {
  description = "Internal hostnames and the address they resolve to"
  value = {
    (adguard_rewrite.apex.domain)     = adguard_rewrite.apex.answer
    (adguard_rewrite.wildcard.domain) = adguard_rewrite.wildcard.answer
  }
}
