# OAuth client from TAILSCALE_OAUTH_CLIENT_ID and TAILSCALE_OAUTH_CLIENT_SECRET,
# with the policy_file and dns write scopes; tailnet "-" is the client's own.
provider "tailscale" {
  tailnet = "-"
  scopes  = ["policy_file", "dns"]
}
