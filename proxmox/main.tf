locals {
  inventory = yamldecode(file("${path.module}/../ansible/inventory.yml"))

  # No defaults: every host sets its node and specs explicitly.
  hosts = merge([for group in values(local.inventory.all.children) : group.hosts]...)

  # A VM unless a host sets `guest_type: lxc`.
  guest_type = { for name, host in local.hosts : name => try(host.guest_type, "vm") }
  containers = { for name, host in local.hosts : name => host if local.guest_type[name] == "lxc" }

  # Every VM host, plus the VM a container replaced while the inventory keeps
  # it as `retired_vm`. Same key as before, so the VM stays in the state and
  # retired_vm only has to repeat its specs; address and login default to the
  # container's and the shared user.
  vms = merge(
    { for name, host in local.hosts : name => host if local.guest_type[name] == "vm" },
    {
      for name, host in local.containers : name => merge(
        {
          proxmox_node = host.proxmox_node
          ansible_host = host.ansible_host
          ansible_user = local.inventory.all.vars.ansible_user
        },
        try({ ipv6_host = host.ipv6_host }, {}),
        host.retired_vm,
      ) if try(host.retired_vm, null) != null
    },
  )

  proxmox_nodes = toset([for vm in values(local.vms) : vm.proxmox_node])
  lxc_nodes     = toset([for host in values(local.containers) : host.proxmox_node])

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

resource "proxmox_download_file" "debian_lxc" {
  for_each = local.lxc_nodes

  node_name    = each.key
  datastore_id = var.file_datastore_id
  content_type = "vztmpl"
  url          = var.debian_lxc_template_url
  file_name    = basename(var.debian_lxc_template_url)
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
  memory_min     = each.value.memory_min
  disk_size      = each.value.disk_size
  data_disk_size = each.value.data_disk_size

  datastore_id         = var.datastore_id
  snippet_datastore_id = var.file_datastore_id
  os                   = local.vm_os[each.key]
  image_file_id        = local.vm_os[each.key] == "arch" ? proxmox_download_file.arch[each.value.proxmox_node].id : proxmox_download_file.debian[each.value.proxmox_node].id

  ipv4_address = "${each.value.ansible_host}/${var.lan_prefix_length}"
  ipv4_gateway = var.lan_gateway
  nameservers  = [var.lan_gateway]

  # Only hosts with ipv6_host get a fixed IPv6 address (see inventory.yml).
  ipv6_address = try(
    "${cidrhost(local.inventory.all.vars.lan_ipv6_prefix, parseint(each.value.ipv6_host, 16))}/${split("/", local.inventory.all.vars.lan_ipv6_prefix)[1]}",
    null
  )

  username        = try(each.value.ansible_user, local.inventory.all.vars.ansible_user)
  ssh_public_keys = local.inventory.all.vars.ssh_authorized_keys

  started = try(each.value.started, true)
}

module "lxc" {
  source   = "./modules/lxc"
  for_each = local.containers

  # A container can take over the address of the VM it replaces: stop that
  # VM (retired_vm.started: false) before the container starts.
  depends_on = [module.vm]

  name           = each.key
  vm_id          = each.value.vm_id
  node_name      = each.value.proxmox_node
  cores          = each.value.cores
  memory         = each.value.memory
  disk_size      = each.value.disk_size
  data_disk_size = each.value.data_disk_size
  data_disk_path = try(each.value.data_disk_path, null)
  keyctl         = try(each.value.lxc_keyctl, false)
  devices        = try(each.value.lxc_devices, [])

  datastore_id     = var.datastore_id
  template_file_id = proxmox_download_file.debian_lxc[each.value.proxmox_node].id

  ipv4_address = "${each.value.ansible_host}/${var.lan_prefix_length}"
  ipv4_gateway = var.lan_gateway
  nameservers  = [var.lan_gateway]

  ipv6_address = try(
    "${cidrhost(local.inventory.all.vars.lan_ipv6_prefix, parseint(each.value.ipv6_host, 16))}/${split("/", local.inventory.all.vars.lan_ipv6_prefix)[1]}",
    null
  )

  ssh_public_keys = local.inventory.all.vars.ssh_authorized_keys
}

# The SeaweedFS VM was called seaweedfs-server; the host is now seaweedfs and
# its group object_storage, as a host and group with the same name clash in
# Ansible. Keeps the VM instead of replacing it.
moved {
  from = module.vm["seaweedfs-server"]
  to   = module.vm["seaweedfs"]
}
