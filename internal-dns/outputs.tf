output "records" {
  description = "Internal hostnames and the address they resolve to"
  value       = module.adguard.records
}

output "tailnet_split_dns" {
  description = "Domain the tailnet resolves through AdGuard Home, and its nameservers"
  value       = { (tailscale_dns_split_nameservers.homelab.domain) = tailscale_dns_split_nameservers.homelab.nameservers }
}
