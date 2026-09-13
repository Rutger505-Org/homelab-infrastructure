output "tailscale_router" {
  description = "Tailscale subnet router"
  value = {
    address = module.tailscale.ipv4_address
    ssh     = module.tailscale.ssh_command
  }
}

output "k3s_server" {
  description = "K3s control plane node"
  value = {
    address = module.k3s_server.ipv4_address
    ssh     = module.k3s_server.ssh_command
  }
}

output "k3s_agent" {
  description = "K3s worker node"
  value = {
    address = module.k3s_agent.ipv4_address
    ssh     = module.k3s_agent.ssh_command
  }
}

output "kubeconfig_command" {
  description = "Fetch the cluster kubeconfig once the server has finished booting. Replace the server address inside it; it points at 127.0.0.1 by default."
  value       = "ssh debian@${module.k3s_server.ipv4_address} sudo cat /etc/rancher/k3s/k3s.yaml | sed 's/127.0.0.1/${module.k3s_server.ipv4_address}/'"
}
