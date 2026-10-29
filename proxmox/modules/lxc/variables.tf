variable "name" {
  description = "Container hostname, also its name in Proxmox"
  type        = string
}

variable "vm_id" {
  description = "Proxmox guest id, shared with the VM ids"
  type        = number
}

variable "node_name" {
  description = "Proxmox node the container runs on"
  type        = string
}

variable "cores" {
  description = "CPU cores"
  type        = number
}

variable "memory" {
  description = "Memory limit in MiB"
  type        = number
}

variable "swap" {
  description = "Swap limit in MiB"
  type        = number
  default     = 256
}

variable "disk_size" {
  description = "Root filesystem size in GiB"
  type        = number
}

variable "data_disk_size" {
  description = "Size in GiB of a separate data volume, 0 for none"
  type        = number
}

variable "data_disk_path" {
  description = "Where the data volume is mounted in the container"
  type        = string
  default     = null
}

variable "keyctl" {
  description = "Allow the keyctl() system call, needed for Docker"
  type        = bool
  default     = false
}

variable "devices" {
  description = "Host devices passed through to the container, e.g. /dev/net/tun"
  type        = list(string)
  default     = []
}

variable "datastore_id" {
  description = "Datastore for the root filesystem and data volume"
  type        = string
}

variable "template_file_id" {
  description = "Container template the root filesystem is created from"
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

variable "ssh_public_keys" {
  description = "Authorized keys for root at creation"
  type        = list(string)
}

variable "startup_order" {
  description = "Boot order on the node, lower starts first; null for no order"
  type        = number
  default     = null
}

variable "startup_delay" {
  description = "Seconds to wait after starting this guest before the next one, null for none"
  type        = number
  default     = null
}
