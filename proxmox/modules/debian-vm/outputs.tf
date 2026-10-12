output "vm_id" {
  description = "Proxmox VM id"
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "ipv4_address" {
  description = "Static address without prefix length"
  value       = split("/", var.ipv4_address)[0]
}
