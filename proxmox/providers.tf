# Endpoint and API token come from PROXMOX_VE_ENDPOINT and PROXMOX_VE_API_TOKEN.
provider "proxmox" {
  insecure = true

  # The Proxmox API cannot write snippets, so cloud-init user data is uploaded over SSH.
  ssh {
    agent    = true
    username = var.proxmox_ssh_username
    # Some settings are root@pam only, and an API token never counts as
    # root@pam: the containers' /dev/net/tun passthrough and keyctl flag. With
    # this, calls under /nodes/{node}/ use a short-lived root@pam ticket the
    # provider mints over the root SSH login above; the rest keeps the token.
    root_ticket = true
  }
}
