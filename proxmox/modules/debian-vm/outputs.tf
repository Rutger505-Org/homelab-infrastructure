output "name" {
  description = "VM name / hostname"
  value       = proxmox_virtual_environment_vm.this.name
}

output "vm_id" {
  description = "Proxmox VM id"
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "ipv4_address" {
  description = "Static address assigned via cloud-init, without the CIDR suffix"
  value       = split("/", var.ipv4_address)[0]
}

output "ssh_command" {
  description = "Ready-to-paste SSH command"
  value       = "ssh ${var.username}@${split("/", var.ipv4_address)[0]}"
}
