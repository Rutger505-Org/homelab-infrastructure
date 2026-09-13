// Prototype: the homelab's Proxmox layer as code.
//
// It replaces the manual "Tailscale" and "Kubernetes" sections of the top-level
// README: creating the VMs, giving them static addresses, joining the tailnet,
// and installing k3s as a two-node cluster. Nobody SSHes in to finish the job.
//
// Ordering matters and is expressed through references, not comments:
//   image -> VMs -> cloud-init -> tailnet join / k3s bootstrap
//   k3s server -> k3s agent (the agent needs the server's address and token)

// --- Base image --------------------------------------------------------------

// Downloaded by Proxmox itself, directly onto the datastore. This is the step
// that removes "upload the Debian ISO" and "build a template first" from the
// manual runbook: VM disks are cloned from this image.
resource "proxmox_download_file" "debian" {
  content_type = "iso"
  datastore_id = var.image_datastore_id
  node_name    = var.node_name
  url          = var.debian_image_url

  // Proxmox only accepts .img/.iso in an iso datastore, so the qcow2 is stored
  // under an .img name. The format is unchanged and the disk import still works.
  file_name = "debian-13-genericcloud-amd64.img"

  // Cloud images are rebuilt in place upstream; without this a re-download
  // would be attempted on every plan.
  overwrite = false
}

// --- Tailnet join credentials -------------------------------------------------

// Minted here rather than pasted in by hand, which is what makes the tailnet
// join part of `apply` instead of a step in a README.
//
// Reusable because all three VMs share it. Not ephemeral: ephemeral nodes are
// removed from the tailnet when they go offline, which is wrong for permanent
// infrastructure. Rotation is `tofu taint` on this resource.
resource "tailscale_tailnet_key" "homelab" {
  reusable      = true
  ephemeral     = false
  preauthorized = true
  description   = "homelab VMs (managed by OpenTofu)"
  expiry        = 3600 // seconds; only needs to outlive the apply
  tags          = [var.tailscale_tag]
}

// --- Shared cluster secret ----------------------------------------------------

// The agent authenticates to the server with this. Generated rather than
// chosen so it never appears in a commit; it lives in state, which is why state
// belongs in the hosted backend and not in a repo.
resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

// --- Tailscale subnet router --------------------------------------------------

// Advertises the LAN into the tailnet, which is what makes MetalLB addresses
// (Grafana, Traefik) reachable remotely without exposing anything publicly.
module "tailscale" {
  source = "./modules/debian-vm"

  name        = "tailscale"
  description = "Tailscale subnet router | OpenTofu"
  vm_id       = var.tailscale_vm.vm_id
  node_name   = var.node_name
  cores       = var.tailscale_vm.cores
  memory      = var.tailscale_vm.memory
  disk_size   = var.tailscale_vm.disk_size

  datastore_id         = var.datastore_id
  snippet_datastore_id = var.snippet_datastore_id
  image_file_id        = proxmox_download_file.debian.id

  ipv4_address = var.tailscale_vm.ipv4_address
  ipv4_gateway = var.ipv4_gateway
  nameservers  = var.nameservers

  ssh_public_keys = var.ssh_public_keys

  tailscale_auth_key = tailscale_tailnet_key.homelab.key
  tailscale_args = concat(
    ["--advertise-tags=${var.tailscale_tag}"],
    var.advertise_lan_route ? ["--advertise-routes=${var.lan_route}"] : [],
  )

  // Subnet routing needs forwarding on, and the Tailscale installer does not
  // enable it for you.
  extra_runcmd = var.advertise_lan_route ? [
    "sysctl -w net.ipv4.ip_forward=1",
    "sysctl -w net.ipv6.conf.all.forwarding=1",
    "printf 'net.ipv4.ip_forward=1\\nnet.ipv6.conf.all.forwarding=1\\n' > /etc/sysctl.d/99-tailscale.conf",
  ] : []
}

// --- K3s control plane --------------------------------------------------------

module "k3s_server" {
  source = "./modules/debian-vm"

  name        = "k3s-server"
  description = "K3s control plane | OpenTofu"
  vm_id       = var.k3s_server.vm_id
  node_name   = var.node_name
  cores       = var.k3s_server.cores
  memory      = var.k3s_server.memory
  disk_size   = var.k3s_server.disk_size

  datastore_id         = var.datastore_id
  snippet_datastore_id = var.snippet_datastore_id
  image_file_id        = proxmox_download_file.debian.id

  ipv4_address = var.k3s_server.ipv4_address
  ipv4_gateway = var.ipv4_gateway
  nameservers  = var.nameservers

  ssh_public_keys    = var.ssh_public_keys
  tailscale_auth_key = tailscale_tailnet_key.homelab.key
  tailscale_args     = ["--advertise-tags=${var.tailscale_tag}"]

  extra_runcmd = [
    // ServiceLB is disabled because MetalLB owns LoadBalancer addresses in
    // kubernetes-infrastructure; leaving both on makes them fight over IPs.
    // This is step 6 of the manual README, now declared instead of typed.
    "mkdir -p /etc/rancher/k3s",
    "printf 'disable:\\n  - servicelb\\nwrite-kubeconfig-mode: \"0644\"\\n' > /etc/rancher/k3s/config.yaml",
    "curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL='${var.k3s_version}' K3S_TOKEN='${random_password.k3s_token.result}' sh -s - server --tls-san ${split("/", var.k3s_server.ipv4_address)[0]}",
  ]
}

// --- K3s worker ---------------------------------------------------------------

module "k3s_agent" {
  source = "./modules/debian-vm"

  name        = "k3s-agent"
  description = "K3s worker | OpenTofu"
  vm_id       = var.k3s_agent.vm_id
  node_name   = var.node_name
  cores       = var.k3s_agent.cores
  memory      = var.k3s_agent.memory
  disk_size   = var.k3s_agent.disk_size

  datastore_id         = var.datastore_id
  snippet_datastore_id = var.snippet_datastore_id
  image_file_id        = proxmox_download_file.debian.id

  ipv4_address = var.k3s_agent.ipv4_address
  ipv4_gateway = var.ipv4_gateway
  nameservers  = var.nameservers

  ssh_public_keys    = var.ssh_public_keys
  tailscale_auth_key = tailscale_tailnet_key.homelab.key
  tailscale_args     = ["--advertise-tags=${var.tailscale_tag}"]

  extra_runcmd = [
    // Cloud-init runs on both VMs at once, so the server's API may not be up
    // yet. Retry rather than depending on lucky timing; k3s-agent exits
    // non-zero on a refused connection and cloud-init would give up.
    "until curl -ksf https://${split("/", var.k3s_server.ipv4_address)[0]}:6443/ping; do echo 'waiting for k3s server'; sleep 10; done",
    "curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL='${var.k3s_version}' K3S_URL='https://${split("/", var.k3s_server.ipv4_address)[0]}:6443' K3S_TOKEN='${random_password.k3s_token.result}' sh -",
  ]

  // The wait loop above handles boot ordering inside the guests; this makes the
  // dependency explicit at the Proxmox level too, so a fresh apply creates the
  // server first instead of racing.
  depends_on = [module.k3s_server]
}
