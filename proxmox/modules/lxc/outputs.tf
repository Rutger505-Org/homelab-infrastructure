output "vm_id" {
  description = "Proxmox guest id"
  value       = proxmox_virtual_environment_container.this.vm_id
}

output "ipv4_address" {
  description = "Static address without prefix length"
  value       = split("/", var.ipv4_address)[0]
}
