# Setting up home lab

Documentation for setting up home lab (again..)

## Proxmox

1. Install Proxmox on both servers
2. Initialize cluster
3. Add one server as slave
4. Setup upload Ubuntu server 26 ISO

## Tailscale

1. Create Tailscale VM
2. Create Bitwarden Tailscale username, password
3. Configure authorized keys
4. Configure 192.168.178.203 as static IP
5. Remotely login, install and login to Tailscale

## Kubernetes

1. Create 2 K3s VMs
2. Create Bitwarden entries for both
3. Configure authorized keys
4. Configure 201, and 202 as static IP addresses
5. Install K3s on 201
6. Install K3s on 202 AS slave (look at official docs)
7. Copy kubeconfig to Bitwarden entry
8. Configure GitHub ORG with new kubeconfig

## Local Image Registry

1. Create a registry VM
2. Create Bitwarden entry for the registry host
3. Configure authorized keys
4. Configure 192.168.178.204 as static IP
5. Install Docker and run `registry:2` with a persistent volume for `/var/lib/registry`
6. Protect it: basic auth via mounted `htpasswd` file, store the credentials in Bitwarden
7. Expose over Tailscale (and/or traefik + cert-manager for TLS at `registry.<domain>`)
8. On both K3s nodes, add the registry to `/etc/rancher/k3s/registries.yaml` (endpoint + auth) and restart K3s
9. Test: `docker push 192.168.178.204:5000/<image>` then pull it from a Deployment

