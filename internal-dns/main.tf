locals {
  domain = "homelab.rutgerpronk.com"

  # Every <service>.homelab.rutgerpronk.com goes to the reverse proxy, which
  # holds the wildcard certificate and routes by name (caddy_routes in
  # ansible/roles/caddy). Only exists in AdGuard Home, so it resolves for
  # LAN clients that use it as DNS server. Outside the LAN the public
  # *.rutgerpronk.com wildcard still answers with the home IP.
  reverse_proxy = "192.168.178.207"
}

resource "adguard_rewrite" "wildcard" {
  domain = "*.${local.domain}"
  answer = local.reverse_proxy
}
