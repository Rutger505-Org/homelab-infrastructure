# Endpoint and API token come from PROXMOX_VE_ENDPOINT and PROXMOX_VE_API_TOKEN.
provider "proxmox" {
  insecure = true

  # The Proxmox API cannot write snippets, so cloud-init user data is uploaded over SSH.
  ssh {
    agent    = true
    username = var.proxmox_ssh_username
  }
}
