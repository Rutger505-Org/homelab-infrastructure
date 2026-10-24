output "vms" {
  description = "Created VMs by name"
  value = {
    for name, vm in module.vm : name => {
      vm_id   = vm.vm_id
      address = vm.ipv4_address
    }
  }
}

output "containers" {
  description = "Created LXC containers by name"
  value = {
    for name, ct in module.lxc : name => {
      vm_id   = ct.vm_id
      address = ct.ipv4_address
    }
  }
}
