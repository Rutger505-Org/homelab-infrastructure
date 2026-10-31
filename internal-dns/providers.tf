# Talks to the AdGuard Home API on the LAN. Password comes from ADGUARD_PASSWORD.
provider "adguard" {
  host     = var.adguard_host
  username = "admin"
  scheme   = "http"
}

# The second instance, same password.
provider "adguard" {
  alias    = "adguard_2"
  host     = var.adguard_2_host
  username = "admin"
  scheme   = "http"
}
