# Setting up home lab

Notes for setting up the home lab (again..).

All VMs run Debian. The Openclaw VM is the exception and runs Arch.

## Proxmox

1. Install Proxmox on both servers
2. Initialize cluster
3. Add one server as slave
4. Upload the Debian server ISO
5. Set static ip to 200. For other installs move to 199, 198, etc.

## VMs as code

`proxmox/` (OpenTofu) creates every VM listed in `ansible/inventory.yml` from the
Debian 13 cloud image, with cloud-init only setting up the `debian` user, SSH keys
and the QEMU guest agent. `ansible/` then configures what runs on it. CI runs both
on every push to main that touches them.

Only the SeaweedFS VM is managed this way. The Tailscale and k3s VMs are still
built by hand, see the sections below.

State lives in Cloudflare R2, encrypted with a passphrase, not in k3s, so it stays
readable when the cluster is gone.

### One-time setup

1. Proxmox API user and token, on one of the nodes:
   ```bash
   pveum user add terraform@pve --comment "OpenTofu"
   pveum acl modify / --users terraform@pve --roles Administrator
   pveum user token add terraform@pve opentofu --privsep 0
   ```
2. Enable the `Snippets` and `Import` content types on the `local` storage (Datacenter, Storage, local, Content).
   VM disks are imported from the cloud image, which Proxmox only allows from `import` content.
3. Generate a CI SSH key with `ssh-keygen -t ed25519 -f homelab-ci -C homelab-ci` and add the
   public key to `/root/.ssh/authorized_keys` on both Proxmox nodes. The API cannot upload
   snippets, so OpenTofu needs SSH for that.
4. Create the R2 bucket `homelab-tofu-state` and an R2 API token with Object Read & Write on it
5. Tailscale: CI joins as `tag:ci-homelab` and reaches the LAN through the existing subnet
   router. The VMs themselves are not in the tailnet.
   - add `tag:ci-homelab` to `tagOwners` in the tailnet policy
   - create an OAuth client with the `auth_keys` write scope and `tag:ci-homelab`
   - allow `tag:ci-homelab` to reach `192.168.178.0/24` on ports 22 and 8006.
     `tag:ci` stays limited to the Kubernetes API.
6. Generate a state passphrase of at least 16 characters and store it in Bitwarden.
   Without it the state cannot be read.

### GitHub configuration

Secrets:
- `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`
- `TOFU_STATE_PASSPHRASE`
- `PROXMOX_VE_API_TOKEN`: `terraform@pve!opentofu=<secret>`
- `HOMELAB_SSH_PRIVATE_KEY`: the CI private key
- `TAILSCALE_CI_HOMELAB_OAUTH_CLIENT_ID`, `TAILSCALE_CI_HOMELAB_OAUTH_SECRET`: the `tag:ci-homelab` client
- `SEAWEEDFS_ADMIN_ACCESS_KEY`, `SEAWEEDFS_ADMIN_SECRET_KEY`: S3 admin credentials

Variables:
- `R2_ENDPOINT`: `https://<account-id>.r2.cloudflarestorage.com`
- `PROXMOX_VE_ENDPOINT`: `https://192.168.178.200:8006/`
- `HOMELAB_SSH_PUBLIC_KEYS`: JSON list with the CI public key and your own, e.g. `["ssh-ed25519 AAAA... homelab-ci"]`

### Running locally

Needed when the Tailscale router is down, since CI reaches the homelab through it.
Run from the LAN, with your SSH key in the agent and authorized on the Proxmox nodes.

```bash
export AWS_ACCESS_KEY_ID=<r2 access key id>
export AWS_SECRET_ACCESS_KEY=<r2 secret>
export AWS_ENDPOINT_URL_S3=https://<account-id>.r2.cloudflarestorage.com
export TF_VAR_state_passphrase=<passphrase>
export TF_VAR_ssh_public_keys='["ssh-ed25519 AAAA..."]'
export PROXMOX_VE_ENDPOINT=https://192.168.178.200:8006/
export PROXMOX_VE_API_TOKEN='terraform@pve!opentofu=<secret>'
export SEAWEEDFS_ADMIN_ACCESS_KEY=<access key>
export SEAWEEDFS_ADMIN_SECRET_KEY=<secret key>

tofu -chdir=proxmox init
tofu -chdir=proxmox apply
cd ansible
ansible-playbook playbook.yml
```

### Adding a VM

Add a group and host to `ansible/inventory.yml` with `ansible_host`, `vm_id`,
`proxmox_node` (e.g. `proxmox-lade`), `cores`, `memory` (MiB), `disk_size` and
`data_disk_size` (GiB, `0` for none). All are required, there are no defaults;
add a play for the group to `ansible/playbook.yml` and push.

Every VM has `prevent_destroy`: removing it from the inventory, `tofu destroy` or a
change that forces a rebuild fails the run. Remove that line in
`proxmox/modules/debian-vm/main.tf` on purpose to rebuild one.

### SeaweedFS

`seaweedfs-server` (`.214`, id 904) runs SeaweedFS (master, volume, filer and S3
gateway in one `weed server` process). Only S3 on port 8333 and SSH are reachable;
the rest listens on localhost and nftables drops everything else.

- Data: `/var/lib/seaweedfs` on its own 60 GB disk (scsi1), separate from the root disk
- Buckets: `seaweedfs_buckets` in the role defaults, objects anonymously readable per file
- Upgrade: bump `seaweedfs_version`
- Not in use yet: the CDN still points at SeaweedFS in k3s until it is moved over

### Known limits

- cloud-init only runs on first boot; changes to it only reach new VMs
- No backups yet; set up vzdump or PBS before relying on the data disk alone

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
