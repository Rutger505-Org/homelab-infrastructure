# Setting up home lab

Documentation for setting up home lab (again..)

All VMs run **Debian**.

## QEMU guest agent (every VM)

Do this for **every** VM below.

In Proxmox, enable the agent in the VM config:

```bash
qm set <vmid> --agent enabled=1
```

Then, on the VM itself:

```bash
sudo apt update
sudo apt install -y qemu-guest-agent
sudo systemctl enable --now qemu-guest-agent
```

Reboot the VM once so Proxmox picks up the agent channel:

```bash
sudo reboot
```

Verify from the Proxmox host:

```bash
qm agent <vmid> ping
```

## Proxmox

1. Install Proxmox on both servers
2. Initialize cluster
3. Add one server as slave
4. Upload Debian server ISO
5. Set static ip to 200, for other installs move to 199, 198, etc.

## Tailscale

1. Create Tailscale VM (Debian)
2. Create Bitwarden Tailscale username, password
3. Configure authorized keys
4. Configure 192.168.178.203 as static IP
5. Enable QEMU guest agent (see above)
6. Remotely login, install and login to Tailscale

## Kubernetes

1. Create 2 K3s VMs (Debian)
2. Create Bitwarden entries for both
3. Configure authorized keys
4. Configure 201, and 202 as static IP addresses
5. Enable QEMU guest agent (see above)
6. Install K3s on 201
7. Install K3s on 202 AS slave (look at official docs)
8. Copy kubeconfig to Bitwarden entry
9. Configure GitHub ORG with new kubeconfig

## Openclaw

1. Create VM (Debian)
2. Create Bitwarden entries for pass
3. Configure authorized keys
4. Configure 204 as static IP address
5. Enable QEMU guest agent (see above)
6. Install openclaw
