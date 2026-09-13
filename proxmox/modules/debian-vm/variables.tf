variable "name" {
  description = "VM name, also used as the hostname"
  type        = string
}

variable "vm_id" {
  description = "Proxmox VM id"
  type        = number
}

variable "node_name" {
  description = "Proxmox node this VM runs on"
  type        = string
}

variable "description" {
  description = "Shown in the Proxmox UI. Worth setting: a VM with no description is a VM nobody dares delete."
  type        = string
  default     = "Managed by OpenTofu"
}

variable "tags" {
  description = "Proxmox tags, handy for scoping API token permissions to a pool later"
  type        = list(string)
  default     = ["opentofu"]
}

variable "cores" {
  description = "vCPU cores"
  type        = number
  default     = 2
}

variable "memory" {
  description = "Memory in MiB"
  type        = number
  default     = 2048
}

variable "disk_size" {
  description = "Root disk size in GiB"
  type        = number
  default     = 20
}

variable "datastore_id" {
  description = "Datastore holding the VM disk"
  type        = string
  default     = "local-lvm"
}

variable "image_file_id" {
  description = "File id of the downloaded cloud image to clone the root disk from"
  type        = string
}

variable "snippet_datastore_id" {
  description = "Datastore with the 'snippets' content type enabled, for cloud-init user data"
  type        = string
  default     = "local"
}

variable "ipv4_address" {
  description = "Static address in CIDR form, e.g. '192.168.178.201/24'"
  type        = string
}

variable "ipv4_gateway" {
  description = "Default gateway"
  type        = string
}

variable "nameservers" {
  description = "DNS servers for the guest"
  type        = list(string)
  default     = ["192.168.178.1"]
}

variable "bridge" {
  description = "Proxmox network bridge to attach to"
  type        = string
  default     = "vmbr0"
}

variable "username" {
  description = "Login user created by cloud-init"
  type        = string
  default     = "debian"
}

variable "ssh_public_keys" {
  description = "Authorised keys for the login user. Password login stays disabled."
  type        = list(string)
}

variable "tailscale_auth_key" {
  description = "Pre-authorised tailnet key. Empty disables the Tailscale step."
  type        = string
  sensitive   = true
  default     = ""
}

variable "tailscale_args" {
  description = "Extra flags for `tailscale up`, e.g. advertising routes"
  type        = list(string)
  default     = []
}

variable "extra_runcmd" {
  description = "Commands appended to cloud-init runcmd, used here to install k3s"
  type        = list(string)
  default     = []
}

variable "extra_packages" {
  description = "Additional apt packages to install on first boot"
  type        = list(string)
  default     = []
}
