variable "name" {
  description = "VM name, also used as hostname"
  type        = string
}

variable "vm_id" {
  description = "Proxmox VM id"
  type        = number
}

variable "node_name" {
  description = "Proxmox node the VM runs on"
  type        = string
}

variable "cores" {
  description = "vCPU cores"
  type        = number
}

variable "memory" {
  description = "Memory in MiB"
  type        = number
}

variable "disk_size" {
  description = "Root disk size in GiB"
  type        = number
}

variable "datastore_id" {
  description = "Datastore for the VM disk and cloud-init drive"
  type        = string
}

variable "snippet_datastore_id" {
  description = "Datastore with the 'snippets' content type enabled"
  type        = string
}

variable "image_file_id" {
  description = "Cloud image the root disk is imported from"
  type        = string
}

variable "ipv4_address" {
  description = "Static address in CIDR notation"
  type        = string
}

variable "ipv4_gateway" {
  description = "Default gateway"
  type        = string
}

variable "nameservers" {
  description = "DNS servers"
  type        = list(string)
}

variable "bridge" {
  description = "Proxmox network bridge"
  type        = string
  default     = "vmbr0"
}

variable "username" {
  description = "Login user created by cloud-init"
  type        = string
  default     = "debian"
}

variable "ssh_public_keys" {
  description = "Authorized keys for the login user"
  type        = list(string)
}
