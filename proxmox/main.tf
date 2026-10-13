locals {
  inventory = yamldecode(file("${path.module}/../ansible/inventory.yml"))

  # No defaults: every host sets its node and specs explicitly.
  vms = merge([for group in values(local.inventory.all.children) : group.hosts]...)

  proxmox_nodes = toset([for vm in values(local.vms) : vm.proxmox_node])

  # `os` is the one optional host var: Debian unless a host sets `os: arch`.
  vm_os      = { for name, vm in local.vms : name => try(vm.os, "debian") }
  arch_nodes = toset([for name, vm in local.vms : vm.proxmox_node if local.vm_os[name] == "arch"])
}

resource "proxmox_download_file" "debian" {
  for_each = local.proxmox_nodes

  node_name    = each.key
  datastore_id = var.file_datastore_id
  content_type = "import"
  url          = var.debian_image_url
  file_name    = "debian-13-genericcloud-amd64.qcow2"
  overwrite    = false
}

resource "proxmox_download_file" "arch" {
  for_each = local.arch_nodes

  node_name    = each.key
  datastore_id = var.file_datastore_id
  content_type = "import"
  url          = var.arch_image_url
  file_name    = "arch-linux-x86_64-cloudimg.qcow2"
  overwrite    = false
  # The pkgbuild.com mirror is slow; the 10 minute default timed out. Proxmox
  # keeps downloading after a timeout, so take over a file it finished.
  upload_timeout      = 3600
  overwrite_unmanaged = true
}

module "vm" {
  source   = "./modules/vm"
  for_each = local.vms

  name           = each.key
  vm_id          = each.value.vm_id
  node_name      = each.value.proxmox_node
  cores          = each.value.cores
  memory         = each.value.memory
  disk_size      = each.value.disk_size
  data_disk_size = each.value.data_disk_size

  datastore_id         = var.datastore_id
  snippet_datastore_id = var.file_datastore_id
  os                   = local.vm_os[each.key]
  image_file_id        = local.vm_os[each.key] == "arch" ? proxmox_download_file.arch[each.value.proxmox_node].id : proxmox_download_file.debian[each.value.proxmox_node].id

  ipv4_address = "${each.value.ansible_host}/${var.lan_prefix_length}"
  ipv4_gateway = var.lan_gateway
  nameservers  = [var.lan_gateway]

  username        = try(each.value.ansible_user, local.inventory.all.vars.ansible_user)
  ssh_public_keys = local.inventory.all.vars.ssh_authorized_keys
}
