locals {
  domain = "homelab.rutgerpronk.com"

  # Every <service>.homelab.rutgerpronk.com goes to the reverse proxy, which
  # holds the wildcard certificate and routes by name (caddy_routes in
  # ansible/roles/caddy). Only exists in AdGuard Home, so it resolves for
  # LAN clients that use it as DNS server. Outside the LAN the public
  # *.rutgerpronk.com wildcard still answers with the home IP.
  reverse_proxy = "192.168.178.207"

  # AdGuard Home's DNS address, for the tailnet split DNS below.
  adguard_dns = "192.168.178.205"
}

# The bare domain, for the landing page linking every service.
resource "adguard_rewrite" "apex" {
  domain = local.domain
  answer = local.reverse_proxy
}

resource "adguard_rewrite" "wildcard" {
  domain = "*.${local.domain}"
  answer = local.reverse_proxy
}

# Blocks the encrypted DNS (DoH) endpoints browsers and apps use to go around
# AdGuard Home, which would also skip the rewrites above. Only the client
# queries are filtered: AdGuard Home's own DoH upstreams resolve through the
# bootstrap servers.
resource "adguard_list_filter" "encrypted_dns_bypass" {
  name = "HaGeZi Encrypted DNS Bypass"
  url  = "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists/adblock/doh.txt"
}

# Split DNS: tailnet devices ask AdGuard Home for homelab.rutgerpronk.com and
# its subdomains, everything else keeps the device's own DNS. Away from home
# the query reaches AdGuard Home through the subnet router, so the rewrite
# above works anywhere the device is in the tailnet.
resource "tailscale_dns_split_nameservers" "homelab" {
  domain      = local.domain
  nameservers = [local.adguard_dns]
}
