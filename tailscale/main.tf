# The whole tailnet policy file: grants, SSH, tag owners, route auto-approval
# and tests. Edits in the admin console are drift and get reverted. Tailscale
# validates it, tests included, during plan.
resource "tailscale_acl" "policy" {
  acl = file("${path.module}/policy.hujson")
}

import {
  to = tailscale_acl.policy
  id = "acl"
}

# Split DNS: tailnet devices ask AdGuard Home for homelab.rutgerpronk.com and
# its subdomains, everything else keeps the device's own DNS. Away from home
# the query reaches AdGuard Home through a subnet router, so the rewrites in
# internal-dns/ work anywhere the device is in the tailnet. Both instances, so
# it keeps working with one node down.
resource "tailscale_dns_split_nameservers" "homelab" {
  domain      = "homelab.rutgerpronk.com"
  nameservers = var.adguard_hosts
}

# Moved here from internal-dns/.
import {
  to = tailscale_dns_split_nameservers.homelab
  id = "homelab.rutgerpronk.com"
}
