// Proxmox API access.
//
// Authentication is an API token, never root@pam with a password. Create a
// dedicated user (e.g. terraform@pve) so the token can be revoked on its own
// and every call it makes is attributable in the Proxmox task log.
//
// Credentials come from the environment, so they are never written to disk:
//   PROXMOX_VE_ENDPOINT   https://192.168.178.200:8006/
//   PROXMOX_VE_API_TOKEN  terraform@pve!terraform=<uuid>
//   PROXMOX_VE_SSH_USERNAME / SSH agent for snippet uploads
provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = var.proxmox_insecure // Proxmox ships a self-signed certificate

  // Cloud-init snippets are uploaded over SSH rather than the API: the Proxmox
  // API has no endpoint for writing into a snippets datastore. This is the one
  // part of the prototype that needs more than an API token.
  ssh {
    agent    = true
    username = var.proxmox_ssh_username
  }
}

// Used only to mint a pre-authorised key so new VMs can join the tailnet
// without anyone logging in interactively. Needs an OAuth client with the
// auth_keys scope, from the Tailscale admin console.
provider "tailscale" {
  oauth_client_id     = var.tailscale_oauth_client_id
  oauth_client_secret = var.tailscale_oauth_client_secret
  scopes              = ["auth_keys"]
}
