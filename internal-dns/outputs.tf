output "records" {
  description = "Internal hostnames and the address they resolve to"
  value       = { (adguard_rewrite.wildcard.domain) = adguard_rewrite.wildcard.answer }
}

output "tailnet_split_dns" {
  description = "Domain the tailnet resolves through AdGuard Home, and its nameservers"
  value       = { (tailscale_dns_split_nameservers.homelab.domain) = tailscale_dns_split_nameservers.homelab.nameservers }
}
