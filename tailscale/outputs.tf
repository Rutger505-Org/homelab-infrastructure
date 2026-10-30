output "split_dns" {
  description = "Domain the tailnet resolves through AdGuard Home, and its nameservers"
  value       = { (tailscale_dns_split_nameservers.homelab.domain) = tailscale_dns_split_nameservers.homelab.nameservers }
}
