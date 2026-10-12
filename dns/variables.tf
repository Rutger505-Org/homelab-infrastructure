variable "state_passphrase" {
  description = "Passphrase that encrypts the state and plan files, at least 16 characters"
  type        = string
  sensitive   = true
}
