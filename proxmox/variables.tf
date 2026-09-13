variable "proxmox_endpoint" {
  description = "Proxmox API endpoint, e.g. 'https://192.168.178.200:8006/'"
  type        = string
}

variable "proxmox_insecure" {
  description = "Skip API certificate verification (Proxmox ships a self-signed certificate)"
  type        = bool
  default     = true
}

variable "proxmox_ssh_username" {
  description = "SSH user on the Proxmox host, used only to upload cloud-init snippets"
  type        = string
  default     = "root"
}

variable "node_name" {
  description = "Proxmox node the prototype VMs are created on"
  type        = string
  default     = "pve"
}

variable "datastore_id" {
  description = "Datastore for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "image_datastore_id" {
  description = "Datastore holding downloaded ISOs and cloud images. Must have the 'iso' content type enabled."
  type        = string
  default     = "local"
}

variable "snippet_datastore_id" {
  description = "Datastore for cloud-init snippets. Must have the 'snippets' content type enabled; see the README."
  type        = string
  default     = "local"
}

variable "debian_image_url" {
  description = "Debian generic cloud image. Pinned to a release rather than 'latest' so an upstream rebuild never silently changes what a rebuilt VM boots."
  type        = string
  default     = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
}

variable "ipv4_gateway" {
  description = "LAN gateway for the VMs"
  type        = string
  default     = "192.168.178.1"
}

variable "nameservers" {
  description = "DNS servers handed to the guests"
  type        = list(string)
  default     = ["192.168.178.1"]
}

variable "ssh_public_keys" {
  description = "Authorised keys installed on every VM"
  type        = list(string)
}

variable "tailscale_oauth_client_id" {
  description = "Tailscale OAuth client id with the auth_keys scope"
  type        = string
  sensitive   = true
}

variable "tailscale_oauth_client_secret" {
  description = "Tailscale OAuth client secret"
  type        = string
  sensitive   = true
}

variable "tailscale_tag" {
  description = "ACL tag applied to nodes joining the tailnet. Must exist in the tailnet policy and be owned by the OAuth client."
  type        = string
  default     = "tag:homelab"
}

variable "advertise_lan_route" {
  description = "Whether the Tailscale VM advertises the LAN subnet, making MetalLB addresses (and Grafana) reachable over the tailnet"
  type        = bool
  default     = true
}

variable "lan_route" {
  description = "Subnet advertised by the Tailscale subnet router"
  type        = string
  default     = "192.168.178.0/24"
}

variable "tailscale_vm" {
  description = "Tailscale subnet router VM: id, address, resources"
  type = object({
    vm_id        = number
    ipv4_address = string
    cores        = optional(number, 1)
    memory       = optional(number, 1024)
    disk_size    = optional(number, 10)
  })
  default = {
    vm_id        = 203
    ipv4_address = "192.168.178.203/24"
  }
}

variable "k3s_server" {
  description = "K3s control-plane node"
  type = object({
    vm_id        = number
    ipv4_address = string
    cores        = optional(number, 2)
    memory       = optional(number, 4096)
    disk_size    = optional(number, 40)
  })
  default = {
    vm_id        = 201
    ipv4_address = "192.168.178.201/24"
  }
}

variable "k3s_agent" {
  description = "K3s worker node"
  type = object({
    vm_id        = number
    ipv4_address = string
    cores        = optional(number, 2)
    memory       = optional(number, 4096)
    disk_size    = optional(number, 40)
  })
  default = {
    vm_id        = 202
    ipv4_address = "192.168.178.202/24"
  }
}

variable "k3s_version" {
  description = "K3s channel or exact version. Pin this before the cluster matters."
  type        = string
  default     = "stable"
}
