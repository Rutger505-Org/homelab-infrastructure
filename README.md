# Setting up home lab

Documentation for setting up home lab (again..)

All VMs run **Debian**, except the Openclaw VM which runs **Arch**.

## Proxmox

1. Install Proxmox on both servers
2. Initialize cluster
3. Add one server as slave
4. Upload Debian server ISO
5. Set static ip to 200, for other installs move to 199, 198, etc.

## Tailscale

1. Create Tailscale VM (Debian) — enable the QEMU guest agent in the Proxmox panel (at creation, or later via **VM > Options > QEMU Guest Agent > Enable**)
2. Create Bitwarden Tailscale username, password
3. Configure authorized keys
4. Configure 192.168.178.203 as static IP
6. Remotely login, install and login to Tailscale

## Kubernetes

1. Create 2 K3s VMs (Debian) — enable the QEMU guest agent in the Proxmox panel (at creation, or later via **VM > Options > QEMU Guest Agent > Enable**)
2. Create Bitwarden entries for both
3. Configure authorized keys
4. Configure 201, and 202 as static IP addresses
5. Install K3s on 201
6. Install K3s on 202 AS slave (look at official docs)
7. Copy kubeconfig to Bitwarden entry
8. Configure GitHub ORG with new kubeconfig

## Openclaw

1. Create VM (Arch) — enable the QEMU guest agent in the Proxmox panel (at creation, or later via **VM > Options > QEMU Guest Agent > Enable**)
2. Create Bitwarden entries for pass
3. Configure authorized keys
4. Configure 204 as static IP address
5. Install openclaw
