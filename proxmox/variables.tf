variable "state_passphrase" {
  description = "Passphrase that encrypts the state and plan files, at least 16 characters"
  type        = string
  sensitive   = true
}

variable "ssh_public_keys" {
  description = "Public keys allowed to log in as the VM user, including the CI key Ansible uses"
  type        = list(string)
}

variable "proxmox_ssh_username" {
  description = "SSH user on the Proxmox nodes, used to upload cloud-init snippets"
  type        = string
  default     = "root"
}

variable "default_proxmox_node" {
  description = "Proxmox node for VMs that do not set proxmox_node in the inventory"
  type        = string
  default     = "proxmox-lade"
}

variable "datastore_id" {
  description = "Datastore for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "file_datastore_id" {
  description = "Datastore with the 'iso' and 'snippets' content types enabled"
  type        = string
  default     = "local"
}

variable "debian_image_url" {
  description = "Debian cloud image. Downloaded once per node and never refreshed, so new VMs keep booting the same image until it is deleted on purpose."
  type        = string
  default     = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
}

variable "lan_prefix_length" {
  description = "Prefix length of the LAN the VMs are on"
  type        = number
  default     = 24
}

variable "lan_gateway" {
  description = "LAN gateway, also used as DNS server"
  type        = string
  default     = "192.168.178.1"
}
