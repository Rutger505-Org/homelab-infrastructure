output "vms" {
  description = "Created VMs by name"
  value = {
    for name, vm in module.vm : name => {
      vm_id   = vm.vm_id
      address = vm.ipv4_address
    }
  }
}
