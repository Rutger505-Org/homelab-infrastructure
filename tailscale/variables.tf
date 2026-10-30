variable "state_passphrase" {
  description = "Passphrase that encrypts the state and plan files, at least 16 characters"
  type        = string
  sensitive   = true
}

variable "adguard_hosts" {
  description = "DNS addresses of the AdGuard Home instances (the adguard group in ansible/inventory.yml)"
  type        = list(string)
  default     = ["192.168.178.205", "192.168.178.206"]
}
