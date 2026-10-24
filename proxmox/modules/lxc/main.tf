terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

resource "proxmox_virtual_environment_container" "this" {
  vm_id       = var.vm_id
  node_name   = var.node_name
  description = "Managed by OpenTofu (homelab-infrastructure)"
  # Same node tag as the VMs; colors are set per node in
  # ansible/proxmox-inventory.yml.
  tags = [var.node_name]

  # Container root is a high uid on the node, not root.
  unprivileged  = true
  started       = true
  start_on_boot = true

  features {
    # systemd in Debian 13 needs it for its sandboxing (ProtectSystem,
    # PrivateTmp) and Docker for its own containers.
    nesting = true
    # Docker (runc) uses the kernel keyring. Root-only to set, see
    # root_ticket in providers.tf.
    keyctl = var.keyctl
  }

  cpu {
    cores = var.cores
  }

  # A cgroup limit, not reserved memory: the node only gives the container
  # what it uses. Swap keeps a short spike from hitting the OOM killer.
  memory {
    dedicated = var.memory
    swap      = var.swap
  }

  disk {
    datastore_id = var.datastore_id
    size         = var.disk_size
  }

  # A separate volume for data that must outlive the root filesystem, like
  # the VMs' scsi1. Proxmox formats and mounts it, so the guest only sees a
  # directory.
  dynamic "mount_point" {
    for_each = var.data_disk_size > 0 ? [var.data_disk_size] : []

    content {
      volume = var.datastore_id
      size   = "${mount_point.value}G"
      path   = var.data_disk_path
      backup = true
    }
  }

  # e.g. /dev/net/tun for Tailscale. Root-only to set, see root_ticket in
  # providers.tf.
  dynamic "device_passthrough" {
    for_each = var.devices

    content {
      path = device_passthrough.value
    }
  }

  initialization {
    hostname = var.name

    ip_config {
      ipv4 {
        address = var.ipv4_address
        gateway = var.ipv4_gateway
      }

      # No gateway: the IPv6 default route comes from the modem's router
      # advertisements, like on the VMs.
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

    # Only root exists in the template. Ansible logs in as root and owns
    # authorized_keys after the first boot (ssh_keys role).
    user_account {
      keys = var.ssh_public_keys
    }
  }

  network_interface {
    name   = "eth0"
    bridge = var.bridge
  }

  operating_system {
    template_file_id = var.template_file_id
    type             = "debian"
  }

  lifecycle {
    # Same as the VMs: no backups yet, so a destroy or forced replacement
    # fails the plan. Remove this line on purpose to rebuild one.
    prevent_destroy = true

    # A new template or SSH key list must not rebuild existing containers;
    # both only matter at creation, Ansible owns the keys after that.
    ignore_changes = [
      operating_system[0].template_file_id,
      initialization[0].user_account,
    ]

    precondition {
      condition     = var.data_disk_size == 0 || var.data_disk_path != null
      error_message = "A container with a data disk needs data_disk_path, where it is mounted."
    }
  }
}
