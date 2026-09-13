terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.113"
    }
  }
}

// A Debian cloud-image VM with cloud-init doing the first-boot configuration.
//
// The point of the prototype: this is not "create a VM, then SSH in and set it
// up by hand". Everything the guest becomes is declared here, so a destroyed
// VM comes back identical without anyone remembering what they typed.

locals {
  // Written to the snippets datastore and handed to cloud-init as user data.
  // yamlencode keeps it valid YAML no matter what ends up in the lists, which
  // hand-written heredocs reliably get wrong the moment a value has a colon.
  cloud_config_body = yamlencode({
    hostname         = var.name
    manage_etc_hosts = true
    package_update   = true
    package_upgrade  = true
    packages         = concat(["qemu-guest-agent", "curl", "ca-certificates"], var.extra_packages)

    users = [
      {
        name                = var.username
        groups              = ["sudo"]
        shell               = "/bin/bash"
        sudo                = "ALL=(ALL) NOPASSWD:ALL"
        ssh_authorized_keys = var.ssh_public_keys
      }
    ]

    // Keys only. A cloud image reachable on the LAN with password auth on is
    // a bad week waiting to happen.
    ssh_pwauth   = false
    disable_root = true

    runcmd = concat(
      [
        // Without the guest agent running, Proxmox cannot report the VM's IP
        // and a graceful shutdown turns into a hard power-off.
        ["systemctl", "enable", "--now", "qemu-guest-agent"],
      ],
      var.tailscale_auth_key != "" ? [
        "curl -fsSL https://tailscale.com/install.sh | sh",
        "tailscale up --auth-key='${var.tailscale_auth_key}' --hostname='${var.name}' ${join(" ", var.tailscale_args)}",
      ] : [],
      var.extra_runcmd,
    )
  })

  // cloud-init requires the #cloud-config header on the very first line.
  cloud_config = "#cloud-config\n${local.cloud_config_body}"
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
  description = var.description
  tags        = var.tags

  // Lets Proxmox see the guest's IP and shut it down cleanly. Paired with the
  // package + systemctl above; enabling it here alone would hang shutdowns.
  agent {
    enabled = true
  }

  stop_on_destroy = true

  cpu {
    cores = var.cores
    // 'host' passes the physical CPU through, which is measurably faster and
    // fine as long as live migration only happens between identical hosts.
    type = "host"
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = var.datastore_id
    // Clone the downloaded cloud image rather than running an installer. This
    // is what removes the manual "build a template first" step entirely.
    import_from = var.image_file_id
    interface   = "scsi0"
    size        = var.disk_size
    discard     = "on"
    ssd         = true
  }

  initialization {
    datastore_id = var.datastore_id

    ip_config {
      ipv4 {
        address = var.ipv4_address
        gateway = var.ipv4_gateway
      }
    }

    dns {
      servers = var.nameservers
    }

    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id
  }

  network_device {
    bridge = var.bridge
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = [
      // The disk image reference changes whenever the upstream cloud image is
      // re-downloaded. Reacting to that would rebuild every VM on a point
      // release, which is not what anyone wants from `tofu apply`.
      disk[0].import_from,
    ]
  }
}
