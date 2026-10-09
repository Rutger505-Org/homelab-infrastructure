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
  cloud_config = "#cloud-config\n${yamlencode({
    hostname         = var.name
    manage_etc_hosts = true
    package_update   = true
    packages         = ["qemu-guest-agent"]
    users = [{
      name                = var.username
      groups              = ["sudo"]
      shell               = "/bin/bash"
      sudo                = "ALL=(ALL) NOPASSWD:ALL"
      ssh_authorized_keys = var.ssh_public_keys
    }]
    ssh_pwauth   = false
    disable_root = true
    runcmd       = [["systemctl", "enable", "--now", "qemu-guest-agent"]]
  })}"
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
  tags        = ["opentofu"]

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

  initialization {
    datastore_id      = var.datastore_id
    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id

    ip_config {
      ipv4 {
        address = var.ipv4_address
        gateway = var.ipv4_gateway
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
    # Re-downloading the base image must not rebuild every existing VM.
    ignore_changes = [disk[0].import_from]
  }
}
