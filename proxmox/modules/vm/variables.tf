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
  description = "Maximum memory in MiB"
  type        = number
}

variable "memory_min" {
  description = "Memory in MiB the balloon never takes back from the guest"
  type        = number

  validation {
    condition     = var.memory_min > 0 && var.memory_min <= var.memory
    error_message = "memory_min must be above 0 (0 disables ballooning) and at most memory."
  }
}

variable "disk_size" {
  description = "Root disk size in GiB"
  type        = number
}

variable "data_disk_size" {
  description = "Size in GiB of an empty second disk (scsi1) for data that must outlive the root disk, 0 for none"
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

variable "os" {
  description = "Distribution of the cloud image: debian or arch"
  type        = string

  validation {
    condition     = contains(["debian", "arch"], var.os)
    error_message = "os must be debian or arch."
  }
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

variable "ipv6_address" {
  description = "Static IPv6 address in CIDR notation, null for none"
  type        = string
  default     = null
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
}

variable "ssh_public_keys" {
  description = "Authorized keys for the login user"
  type        = list(string)
}
