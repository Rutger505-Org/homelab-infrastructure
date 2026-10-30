variable "state_passphrase" {
  description = "Passphrase that encrypts the state and plan files, at least 16 characters"
  type        = string
  sensitive   = true
}

variable "adguard_host" {
  description = "AdGuard Home web UI address as host[:port]"
  type        = string
  default     = "192.168.178.205"
}

variable "adguard_2_host" {
  description = "Second AdGuard Home web UI address as host[:port]"
  type        = string
  default     = "192.168.178.206"
}
