locals {
  domain = "homelab.rutgerpronk.com"

  # <name>.homelab.rutgerpronk.com => LAN address. These only exist in AdGuard
  # Home, so they resolve for LAN clients that use it as DNS server. Outside the
  # LAN the public *.rutgerpronk.com wildcard still answers with the home IP.
  # DNS has no ports: services that are not on 80/443 keep theirs in the URL.
  records = {
    adguard         = "192.168.178.205" # :80
    openclaw        = "192.168.178.206" # :18789
    proxmox-lade    = "192.168.178.200" # :8006
    proxmox-prodesk = "192.168.178.199" # :8006
    # Traefik in k3s. Needs a Traefik route for this host before it serves
    # Grafana; for now Grafana is still public on grafana.rutgerpronk.com.
    grafana = "192.168.178.230"
  }
}

resource "adguard_rewrite" "this" {
  for_each = local.records

  domain = "${each.key}.${local.domain}"
  answer = each.value
}
