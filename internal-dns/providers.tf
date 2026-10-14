# Talks to the AdGuard Home API on the LAN. Password comes from ADGUARD_PASSWORD.
provider "adguard" {
  host     = var.adguard_host
  username = "admin"
  scheme   = "http"
}

# Tailnet DNS settings. OAuth client from TAILSCALE_OAUTH_CLIENT_ID and
# TAILSCALE_OAUTH_CLIENT_SECRET, with the dns scope; tailnet "-" is the
# client's own tailnet.
provider "tailscale" {
  tailnet = "-"
  scopes  = ["dns"]
}
