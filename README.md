# Setting up home lab

Notes for setting up the home lab (again..).

All VMs run Debian. The Openclaw VM is the exception and runs Arch.

## Proxmox

1. Install Proxmox on both servers
2. Initialize cluster
3. Add one server as slave
4. Upload the Debian server ISO
5. Set static ip to 200. For other installs move to 199, 198, etc.

## VMs as code (work in progress)

`proxmox/` (OpenTofu) creates every VM listed in `ansible/inventory.yml`, and
`ansible/` installs Tailscale and k3s on them. CI runs both on every push to
main that touches them. It currently builds a parallel test cluster on
`.211`–`.213` (ids 901–903); the manual sections below still describe the live VMs.

State lives in Cloudflare R2, encrypted with a passphrase, not in k3s: it
describes the VMs k3s runs on, so it has to survive the cluster.

### One-time setup

1. Proxmox API user and token, on one of the nodes:
   ```bash
   pveum user add terraform@pve --comment "OpenTofu"
   pveum acl modify / --users terraform@pve --roles Administrator
   pveum user token add terraform@pve opentofu --privsep 0
   ```
2. Enable the `Snippets` content type on the `local` storage (Datacenter, Storage, local, Content)
3. Generate a CI SSH key with `ssh-keygen -t ed25519 -f homelab-ci -C homelab-ci` and add the
   public key to `/root/.ssh/authorized_keys` on both Proxmox nodes. The API cannot upload
   snippets, so OpenTofu needs SSH for that.
4. Create the R2 bucket `homelab-tofu-state` and an R2 API token with Object Read & Write on it
5. Tailscale:
   - add `tag:homelab` to `tagOwners` in the tailnet policy
   - create an OAuth client with the `auth_keys` write scope and `tag:homelab`
   - allow `tag:ci` to reach `192.168.178.0/24` on ports 22 and 8006
6. Generate a state passphrase of at least 16 characters and store it in Bitwarden.
   Without it the state cannot be read.
7. Check the Proxmox node name. VMs default to `pve`; set `proxmox_node` per host in
   the inventory otherwise.

### GitHub configuration

Secrets:
- `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`
- `TOFU_STATE_PASSPHRASE`
- `PROXMOX_VE_API_TOKEN`: `terraform@pve!opentofu=<secret>`
- `HOMELAB_SSH_PRIVATE_KEY`: the CI private key
- `TAILSCALE_HOMELAB_OAUTH_SECRET`: the `tag:homelab` OAuth client secret
- `TAILSCALE_OAUTH_CLIENT_ID`, `TAILSCALE_OAUTH_SECRET`: the `tag:ci` client, same as kubernetes-infrastructure

Variables:
- `R2_ENDPOINT`: `https://<account-id>.r2.cloudflarestorage.com`
- `PROXMOX_VE_ENDPOINT`: `https://192.168.178.200:8006/`
- `HOMELAB_SSH_PUBLIC_KEYS`: JSON list with the CI public key and your own, e.g. `["ssh-ed25519 AAAA... homelab-ci"]`

### Bootstrap from a laptop

CI reaches the homelab through Tailscale, and the Tailscale router is one of these
VMs, so after a rebuild the first run is always local, from the LAN. Your SSH key
must be in the agent and authorized on the Proxmox nodes.

```bash
export AWS_ACCESS_KEY_ID=<r2 access key id>
export AWS_SECRET_ACCESS_KEY=<r2 secret>
export AWS_ENDPOINT_URL_S3=https://<account-id>.r2.cloudflarestorage.com
export TF_VAR_state_passphrase=<passphrase>
export TF_VAR_ssh_public_keys='["ssh-ed25519 AAAA..."]'
export PROXMOX_VE_ENDPOINT=https://192.168.178.200:8006/
export PROXMOX_VE_API_TOKEN='terraform@pve!opentofu=<secret>'
export TAILSCALE_HOMELAB_OAUTH_SECRET=<tskey-client-...>

tofu -chdir=proxmox init
tofu -chdir=proxmox apply
cd ansible
ansible-playbook playbook.yml
```

Then fetch the kubeconfig and replace `127.0.0.1` with the server address:

```bash
ssh debian@192.168.178.211 sudo cat /etc/rancher/k3s/k3s.yaml
```

### Adding a VM

Add a host to a group in `ansible/inventory.yml` with `ansible_host` and `vm_id`
(`cores`, `memory`, `disk_size` and `proxmox_node` are optional) and push.

### Known limits

- Rebuilding the Tailscale router from CI cuts CI's own route to the LAN mid-run
- k3s is only installed, not upgraded: the installer is skipped once k3s exists
- A destroyed VM stays in the tailnet until removed in the admin console
- No backups yet; set up vzdump or PBS before trusting automated rebuilds

## Tailscale

1. Create the Tailscale VM (Debian). Enable the QEMU guest agent in the Proxmox panel, at creation or later under VM, Options, QEMU Guest Agent, Enable
2. Create Bitwarden Tailscale username, password
3. Configure authorized keys
4. Configure 192.168.178.203 as static IP
5. Log in remotely, install Tailscale, and log in

## Kubernetes

1. Create 2 K3s VMs (Debian). Enable the QEMU guest agent in the Proxmox panel, at creation or later under VM, Options, QEMU Guest Agent, Enable
2. Create Bitwarden entries for both
3. Configure authorized keys
4. Configure 201 and 202 as static IP addresses
5. Install K3s on 201
6. Disable the bundled ServiceLB on master node
```bash
sudo tee -a /etc/rancher/k3s/config.yaml <<'EOF'
disable:
  - servicelb
EOF
sudo systemctl restart k3s
# no svclb-* daemonsets should remain
kubectl get ds -n kube-system | grep svclb
```
7. Install K3s on 202 as slave (look at official docs)
8. Copy kubeconfig to the Bitwarden entry
9. Configure the GitHub org with the new kubeconfig

## Openclaw

1. Create the VM (Arch). Enable the QEMU guest agent in the Proxmox panel, at creation or later under VM, Options, QEMU Guest Agent, Enable
2. Create Bitwarden entries for the password
3. Configure authorized keys
4. Configure 204 as static IP address
5. Install openclaw
