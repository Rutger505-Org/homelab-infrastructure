terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

locals {
  # Only what Ansible needs to take over: a user with keys, and the guest agent
  # that Proxmox waits on to report the VM's address.
  # Arch does not support partial upgrades: installing on top of a fresh
  # package database without upgrading can break the system. Only set for Arch
  # so the Debian snippets stay byte for byte the same.
  cloud_config = "#cloud-config\n${yamlencode(merge(var.os == "arch" ? { package_upgrade = true } : {}, {
    hostname         = var.name
    manage_etc_hosts = true
    package_update   = true
    packages         = ["qemu-guest-agent"]
    users = [{
      name                = var.username
      groups              = [var.os == "arch" ? "wheel" : "sudo"]
      shell               = "/bin/bash"
      sudo                = "ALL=(ALL) NOPASSWD:ALL"
      ssh_authorized_keys = var.ssh_public_keys
    }]
    ssh_pwauth   = false
    disable_root = true
    runcmd       = [["systemctl", "enable", "--now", "qemu-guest-agent"]]
  }))}"
}

resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = var.snippet_datastore_id
  node_name    = var.node_name

  source_raw {
    data      = local.cloud_config
    file_name = "${var.name}-cloud-config.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  name        = var.name
  vm_id       = var.vm_id
  node_name   = var.node_name
  description = "Managed by OpenTofu (homelab-infrastructure)"
  # The node tag shows where a VM runs; colors are set per node in
  # ansible/proxmox-inventory.yml.
  tags = [var.node_name]

  stop_on_destroy = true

  agent {
    enabled = true
  }

  cpu {
    cores = var.cores
    type  = "host"
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = var.datastore_id
    import_from  = var.image_file_id
    interface    = "scsi0"
    size         = var.disk_size
    discard      = "on"
    ssd          = true
  }

  dynamic "disk" {
    for_each = var.data_disk_size > 0 ? [var.data_disk_size] : []

    content {
      datastore_id = var.datastore_id
      interface    = "scsi1"
      size         = disk.value
      discard      = "on"
      ssd          = true
    }
  }

  initialization {
    datastore_id      = var.datastore_id
    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id

    ip_config {
      ipv4 {
        address = var.ipv4_address
        gateway = var.ipv4_gateway
      }

      # No gateway: the IPv6 default route comes from the modem's router
      # advertisements, and LAN clients reach the address on-link anyway.
      dynamic "ipv6" {
        for_each = var.ipv6_address == null ? [] : [var.ipv6_address]

        content {
          address = ipv6.value
        }
      }
    }

    dns {
      servers = var.nameservers
    }
  }

  network_device {
    bridge = var.bridge
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    # These VMs hold data without backups yet: a destroy or forced replacement
    # fails the plan instead. Remove this line on purpose to rebuild one.
    prevent_destroy = true

    # Re-downloading the base image must not rebuild every existing VM.
    # Cloud-init only runs on first boot and Ansible owns the config after
    # that (e.g. ssh_authorized_keys), so a changed snippet must not force a
    # replacement either. New VMs still get the current snippet.
    ignore_changes = [
      disk[0].import_from,
      initialization[0].user_data_file_id,
    ]
  }
}
