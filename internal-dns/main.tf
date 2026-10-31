locals {
  domain = "homelab.rutgerpronk.com"

  # Every <service>.homelab.rutgerpronk.com goes to the reverse proxy, which
  # holds the wildcard certificate and routes by name (caddy_routes in
  # ansible/roles/caddy). Only exists in AdGuard Home, so it resolves for
  # LAN clients that use it as DNS server. Outside the LAN the public
  # *.rutgerpronk.com wildcard still answers with the home IP.
  reverse_proxy = "192.168.178.207"
}

# Both AdGuard Home instances (the adguard group in ansible/inventory.yml)
# get the same rewrites and lists: DHCP clients use either one.
module "adguard" {
  source = "./modules/adguard"
  providers = {
    adguard = adguard
  }

  domain        = local.domain
  reverse_proxy = local.reverse_proxy
}

module "adguard_2" {
  source = "./modules/adguard"
  providers = {
    adguard = adguard.adguard_2
  }

  domain        = local.domain
  reverse_proxy = local.reverse_proxy
}

moved {
  from = adguard_rewrite.apex
  to   = module.adguard.adguard_rewrite.apex
}

moved {
  from = adguard_rewrite.wildcard
  to   = module.adguard.adguard_rewrite.wildcard
}

moved {
  from = adguard_list_filter.encrypted_dns_bypass
  to   = module.adguard.adguard_list_filter.encrypted_dns_bypass
}

# Split DNS moved to tailscale/, which imports it. Only drop it from this
# state; the tailscale provider and its secrets go once this has applied.
removed {
  from = tailscale_dns_split_nameservers.homelab

  lifecycle {
    destroy = false
  }
}
