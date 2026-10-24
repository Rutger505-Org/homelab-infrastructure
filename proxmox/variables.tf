variable "state_passphrase" {
  description = "Passphrase that encrypts the state and plan files, at least 16 characters"
  type        = string
  sensitive   = true
}

variable "proxmox_ssh_username" {
  description = "SSH user on the Proxmox nodes, used to upload cloud-init snippets"
  type        = string
  default     = "root"
}

variable "datastore_id" {
  description = "Datastore for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "file_datastore_id" {
  description = "Datastore with the 'import' and 'snippets' content types enabled"
  type        = string
  default     = "local"
}

variable "debian_image_url" {
  description = "Debian cloud image. Downloaded once per node and never refreshed, so new VMs keep booting the same image until it is deleted on purpose."
  type        = string
  default     = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
}

variable "arch_image_url" {
  description = "Arch Linux cloud image, for hosts with `os: arch`. Downloaded once per node and never refreshed, like the Debian image."
  type        = string
  default     = "https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2"
}

variable "debian_lxc_template_url" {
  description = "Debian container template, for hosts with `guest_type: lxc`. Downloaded once per node and never refreshed, like the cloud images; new containers keep using it until it is deleted on purpose."
  type        = string
  default     = "http://download.proxmox.com/images/system/debian-13-standard_13.6-1_amd64.tar.zst"
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
