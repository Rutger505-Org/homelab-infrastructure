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

Only the SeaweedFS, Home Assistant and AdGuard Home VMs are managed this way. The Tailscale and k3s VMs are still
built by hand, see the sections below.

The hand-built VMs (K3s-1, K3s-2, Tailscale, OpenClaw) are imported into the same
state by `proxmox/manual-vms.tf`, mirroring their live config. OpenTofu tracks them
and guards them with `prevent_destroy`, but cannot rebuild them: their OS and
services are still set up by hand.

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
- `MQTT_USERNAME`, `MQTT_PASSWORD`: Mosquitto login on the Home Assistant VM
- `ADGUARD_ADMIN_PASSWORD_HASH`: bcrypt hash of the AdGuard Home web UI password

Variables:
- `R2_ENDPOINT`: `https://<account-id>.r2.cloudflarestorage.com`
- `PROXMOX_VE_ENDPOINT`: `https://192.168.178.200:8006/`

### Running locally

Needed when the Tailscale router is down, since CI reaches the homelab through it.
Run from the LAN, with your SSH key in the agent and authorized on the Proxmox nodes.

```bash
export AWS_ACCESS_KEY_ID=<r2 access key id>
export AWS_SECRET_ACCESS_KEY=<r2 secret>
export AWS_ENDPOINT_URL_S3=https://<account-id>.r2.cloudflarestorage.com
export TF_VAR_state_passphrase=<passphrase>
export PROXMOX_VE_ENDPOINT=https://192.168.178.200:8006/
export PROXMOX_VE_API_TOKEN='terraform@pve!opentofu=<secret>'
export SEAWEEDFS_ADMIN_ACCESS_KEY=<access key>
export SEAWEEDFS_ADMIN_SECRET_KEY=<secret key>
export MQTT_USERNAME=<mqtt user>
export MQTT_PASSWORD=<mqtt password>
export ADGUARD_ADMIN_PASSWORD_HASH='<bcrypt hash>'

tofu -chdir=proxmox init
tofu -chdir=proxmox apply
cd ansible
ansible-playbook playbook.yml
```

### Proxmox nodes

`ansible/proxmox.yml` configures the nodes themselves over root SSH (the
`homelab-ci` key from the one-time setup), using `ansible/proxmox-inventory.yml`.
That is a separate inventory so OpenTofu and the VM plays never see the nodes.
CI runs it after the VM playbook; locally:
`ansible-playbook -i proxmox-inventory.yml proxmox.yml`.

- Subscription nag: `/usr/local/bin/pve-remove-nag.sh` patches the "No valid
  subscription" popup out of `proxmoxlib.js`, and an apt hook
  (`/etc/apt/apt.conf.d/no-nag-script`) re-runs it after every upgrade. The run
  fails if a widget toolkit update changes the code so the patch no longer applies.
  Hard-refresh the browser (Ctrl+Shift+R) after the first run.

### SSH keys

`ssh_authorized_keys` in `ansible/inventory.yml` is the exact `authorized_keys` of
the login user on every VM in the inventory. Add or remove a
key there and merge; the deploy rewrites the file on every VM and removes keys that
are not listed. Keep the `homelab-ci` key, the run refuses a list without it.
New VMs get the same list through cloud-init.

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

### Home Assistant

`home-assistant` (`.215`, id 905, on `proxmox-prodesk`) runs Home Assistant and a
Mosquitto broker as Docker Compose services (`/etc/home-assistant/compose.yaml`). Built for
[motorized-blinds](https://github.com/Rutger505/motorized-blinds): the drivers built with the
`mqtt` feature announce themselves through MQTT discovery and show up as covers.

- Web UI: `http://192.168.178.215:8123`, LAN only. Onboarding creates the owner account
- MQTT: `192.168.178.215:1883`, anonymous off, one user from `MQTT_USERNAME`/`MQTT_PASSWORD`.
  In Home Assistant add the MQTT integration with broker `localhost`
- Home Assistant uses host networking so mDNS/SSDP discovery works; nftables allows
  SSH, 8123, 1883 and mDNS/SSDP only
- Data: `/srv/home-assistant` on its own 10 GB disk (scsi1): `config/` and `mosquitto/data`
- Upgrade: bump `home_assistant_version` / `home_assistant_mosquitto_version` in the role defaults

Flash a blind driver against it, from `motorized-blinds/driver`:

```sh
BLIND_ID=1 WIFI_SSID=... WIFI_PASSWORD=... MQTT_BROKER=192.168.178.215 \
  MQTT_USERNAME=... MQTT_PASSWORD=... \
  cargo run --release --no-default-features --features mqtt
```

### AdGuard Home

`adguard-home` (`.205`, id 906, on `proxmox-prodesk`) runs AdGuard Home as the LAN DNS
resolver with ad blocking. Only SSH, DNS (53 TCP/UDP) and the web UI on port 80 are
reachable; nftables drops everything else.

- Web UI: http://192.168.178.205, user `admin`, password in Bitwarden
- Config: Ansible seeds `/var/lib/adguardhome/AdGuardHome.yaml` once (upstreams, admin
  user, ports). AdGuard Home owns that file afterwards, so change settings, blocklists
  and rewrites in the web UI. A rebuilt VM starts again from the seed.
- Password: the seed only takes a bcrypt hash, e.g. `htpasswd -nbBC 10 "" <password> | tr -d ':\n'`.
  Changing the secret does not change the password of a running instance.
- Upgrade: bump `adguard_home_version`; the built-in updater is off
- Clients only use it once the Ziggo modem hands it out as DNS server: set
  `192.168.178.205` by hand in the modem's DHCP/LAN settings. AdGuard Home does not run
  DHCP, the modem stays the only DHCP server. If the modem has no DNS field, set it per device
- Single instance: when the VM is down, LAN clients lose DNS. Set the modem's DNS back to
  automatic to fall back

### Known limits

- cloud-init only runs on first boot; changes to it only reach new VMs (SSH keys are
  the exception, Ansible keeps those in sync)
- No backups yet; set up vzdump or PBS before relying on the data disk alone

## DNS as code

`dns/` (OpenTofu) manages every record in the Cloudflare zones `rutgerpronk.com` and
`rutgerpronk.nl`. CI plans on pull requests and applies on push to main. It uses the
same R2 bucket and passphrase as `proxmox/`, under its own state key, so DNS changes
never wait on a Proxmox plan.

Change records here, not in the Cloudflare dashboard: anything changed by hand shows up
as drift and is reverted on the next apply.

### One-time setup

1. Create a Cloudflare API token with `Zone : DNS : Edit`, `Zone : Single Redirect : Edit` and `Zone : Zone : Read` on both zones
2. Store it as the GitHub secret `CLOUDFLARE_DNS_API_TOKEN`

### Running locally

```sh
export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... AWS_ENDPOINT_URL_S3=...
export TF_VAR_state_passphrase=...
export CLOUDFLARE_API_TOKEN=...
tofu -chdir=dns init
tofu -chdir=dns plan
```

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
