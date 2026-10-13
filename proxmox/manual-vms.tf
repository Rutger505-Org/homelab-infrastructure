# Hand-built VMs (see the README sections below), imported as they are so
# OpenTofu tracks them. Every attribute mirrors the live config: a plan against
# them must show no changes. Nothing here reinstalls or reconfigures them.
# The one exception is the node tag, which only changes metadata.
locals {
  manual_vms = {
    tailscale = {
      name      = "Tailscale"
      vm_id     = 102
      node_name = "proxmox-lade"
      cores     = 1
      memory    = 512
      disk_size = 15
      mac       = "BC:24:11:E9:75:CA"
      cdrom     = "none"
    }
    openclaw = {
      name      = "OpenClaw"
      vm_id     = 103
      node_name = "proxmox-lade"
      cores     = 4
      memory    = 6144
      disk_size = 65
      mac       = "BC:24:11:48:E5:B6"
      cdrom     = "local:iso/archlinux-2026.08.01-x86_64.iso"
    }
  }
}

import {
  for_each = local.manual_vms
  to       = proxmox_virtual_environment_vm.manual[each.key]
  id       = "${each.value.node_name}/${each.value.vm_id}"
}

resource "proxmox_virtual_environment_vm" "manual" {
  for_each = local.manual_vms

  name      = each.value.name
  vm_id     = each.value.vm_id
  node_name = each.value.node_name
  tags      = [each.value.node_name]

  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["scsi0", "ide2", "net0"]

  agent {
    enabled = true
  }

  cpu {
    cores   = each.value.cores
    sockets = 1
    type    = "x86-64-v2-AES"
  }

  # The provider leaves the block out of state when memory is its 512 MiB
  # default, so declaring it there would show a change.
  dynamic "memory" {
    for_each = each.value.memory == 512 ? [] : [each.value.memory]

    content {
      dedicated = memory.value
    }
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = each.value.disk_size
    iothread     = true
  }

  # ide2 (CD drive, `cdrom` in the locals) is left out: the provider does not
  # import it, and declaring it would rewrite the drive on apply.

  network_device {
    bridge      = "vmbr0"
    mac_address = each.value.mac
    firewall    = true
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    # Hand-built with no way to recreate them from code: never destroy or replace.
    prevent_destroy = true
    # Power state is managed by hand: during cutover the old VMs are shut down
    # and must stay down, their addresses are reused by the managed VMs.
    ignore_changes = [started]
  }
}
