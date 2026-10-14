# Setting up home lab

Notes for setting up the home lab (again..).

All VMs run Debian. The OpenClaw VM is the exception and runs Arch.

## Proxmox

1. Install Proxmox on both servers
2. Initialize cluster
3. Add one server as slave
4. Upload the Debian server ISO
5. Set static ip to 200. For other installs move to 199, 198, etc.

## Addresses

Static, on 192.168.178.0/24, outside the modem's DHCP range. Gateway `.1`.

- `.199`-`.200`: Proxmox nodes, `.200` proxmox-lade, `.199` proxmox-prodesk
- `.201`-`.229`: VMs. A replacement VM takes over the address of the VM it replaces
- `.230`-`.250`: MetalLB, Kubernetes LoadBalancer services (Traefik on `.230`)

The VM addresses are `ansible_host` in `ansible/inventory.yml`; keep this list in sync:

- `.201` k3s-1 (server), `.202` k3s-2 (agent)
- `.205` AdGuard Home
- `.210` OpenClaw
- `.213` Tailscale subnet router
- `.214` SeaweedFS (`cdn.rutgerpronk.com`)
- `.215` Home Assistant
- Free: `.203`, `.204`, `.206`-`.209`, `.211`, `.212`, `.216`-`.229`

Changing `ansible_host` changes the VM's cloud-init network config. Proxmox derives
the cloud-init instance id from that config, so on the next boot cloud-init sees a new
instance and applies the address (and generates new SSH host keys).

## VMs as code

`proxmox/` (OpenTofu) creates every VM listed in `ansible/inventory.yml` from the
Debian 13 cloud image (or the Arch cloud image for hosts with `os: arch`), with
cloud-init only setting up the login user, SSH keys and the QEMU guest agent.
`ansible/` then configures what runs on it. CI runs both on every push to main
that touches them (see CI below).

Managed this way: SeaweedFS, Home Assistant, AdGuard Home, the reverse proxy, k3s-1,
k3s-2, tailscale and OpenClaw. No hand-built VMs are left.

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
- `K3S_TOKEN`: shared secret the k3s agents join with, e.g. `openssl rand -hex 32`
- `K3S_CA_BUNDLE`: the cluster CAs, see k3s
- `TAILSCALE_ROUTER_OAUTH_SECRET`: OAuth client secret for the subnet router, see Tailscale router
- `OPENCLAW_ENV`: contents of `~/.openclaw/.env` on the OpenClaw VM
- `OPENCLAW_SSH_PRIVATE_KEY`: SSH key of the OpenClaw VM, with access to `Rutger505/dev-env` and `Rutger505/openclaw-config`
- `OPENCLAW_READONLY_KUBECONFIG`: the read-only kubeconfig, see kubernetes-infrastructure `4-rbac`
- `MQTT_USERNAME`, `MQTT_PASSWORD`: Mosquitto login on the Home Assistant VM
- `ADGUARD_ADMIN_PASSWORD_HASH`: bcrypt hash of the AdGuard Home web UI password
- `ADGUARD_ADMIN_PASSWORD`: the same password in plain text, for `internal-dns/`
- `CLOUDFLARE_DNS_API_TOKEN` (shared with `dns/`): the reverse proxy uses it for the DNS-01
  challenge of its wildcard certificate

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
export K3S_TOKEN=<token> TAILSCALE_ROUTER_OAUTH_SECRET=<secret>
export OPENCLAW_ENV="$(cat .env)" OPENCLAW_SSH_PRIVATE_KEY="$(cat id_ed25519)"
export OPENCLAW_READONLY_KUBECONFIG="$(cat readonly.kubeconfig)"
export MQTT_USERNAME=<mqtt user>
export MQTT_PASSWORD=<mqtt password>
export ADGUARD_ADMIN_PASSWORD_HASH='<bcrypt hash>'
export CLOUDFLARE_API_TOKEN=<cloudflare dns token>

tofu -chdir=proxmox init
tofu -chdir=proxmox apply
cd ansible
ansible-playbook playbook.yml
```

### CI

`.github/workflows/deploy.yaml` runs OpenTofu, then one Ansible job per service, in
parallel. Each job runs the playbook limited to its inventory group, so a failing
service does not stop the others. `.github/deploy-services.yaml` maps changed files
to services: a role change deploys that service only, while a change to the
inventory, `playbook.yml`, `ansible.cfg`, the `ssh_keys` role or `proxmox/` deploys
every VM service. Run the workflow by hand to deploy everything, e.g. to undo manual
changes on a VM.

- Push to main: `tofu apply` and `ansible-playbook --diff`.
- Pull request: `tofu plan` and `ansible-playbook --check --diff` against the live
  VMs. VMs the PR adds are skipped, since they do not exist yet. Read-only probe
  commands (`blkid`, `k3s --version` and so on) need `check_mode: false`;
  otherwise check mode skips them and the tasks after them report changes that
  will not happen.
- Deploys queue behind each other. PR runs use their own concurrency group, so they
  never hold up a deploy, and a new push cancels the PR's running check.

### Proxmox nodes

`ansible/proxmox.yml` configures the nodes themselves over root SSH (the
`homelab-ci` key from the one-time setup), using `ansible/proxmox-inventory.yml`.
That is a separate inventory so OpenTofu and the VM plays never see the nodes.
CI runs it as the `proxmox` service; locally:
`ansible-playbook -i proxmox-inventory.yml proxmox.yml`.

- Subscription nag: `/usr/local/bin/pve-remove-nag.sh` patches the "No valid
  subscription" popup out of `proxmoxlib.js`, and an apt hook
  (`/etc/apt/apt.conf.d/no-nag-script`) re-runs it after every upgrade. The run
  fails if a widget toolkit update changes the code so the patch no longer applies.
  Hard-refresh the browser (Ctrl+Shift+R) after the first run.
- Tag colors: OpenTofu tags every VM with the node it runs on (`proxmox-lade`,
  `proxmox-prodesk`), next to `opentofu` on the VMs it created. The colors are
  a datacenter option set once for the cluster: `opentofu` in the
  `proxmox_tag_colors` role defaults, each node tag through `proxmox_tag_color`
  in `ansible/proxmox-inventory.yml`. The role owns the whole `tag-style`
  value, so tag style changes made in the UI get overwritten.

### SSH keys

`ssh_authorized_keys` in `ansible/inventory.yml` is the exact `authorized_keys` of
the login user on every VM in the inventory. Add or remove a
key there and merge; the deploy rewrites the file on every VM and removes keys that
are not listed. Keep the `homelab-ci` key, the run refuses a list without it.
New VMs get the same list through cloud-init.

A host can add keys of its own with `ssh_extra_authorized_keys` (host var, appended to
the list), e.g. to let an old VM copy its state over to its replacement.

### Adding a VM

Add a group and host to `ansible/inventory.yml` with `ansible_host`, `vm_id`,
`proxmox_node` (e.g. `proxmox-lade`), `cores`, `memory` (MiB), `disk_size` and
`data_disk_size` (GiB, `0` for none). All are required, there are no defaults;
add a play for the group to `ansible/playbook.yml`, add the group with its role
path to `.github/deploy-services.yaml` and push.

Optional: `os: arch` for the Arch cloud image (default `debian`), and
`ansible_user` to name the login user something other than `debian`. On Arch it
is in `wheel` instead of `sudo`.

Every VM has `prevent_destroy`: removing it from the inventory, `tofu destroy` or a
change that forces a rebuild fails the run. Remove that line in
`proxmox/modules/vm/main.tf` on purpose to rebuild one.

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
resolver and DHCP server, with ad blocking. Only SSH, DNS (53 TCP/UDP), DHCP (67 UDP) and
the web UI on port 80 are reachable; nftables drops everything else.

- Web UI: http://192.168.178.205, user `admin`, password in Bitwarden
- Config: Ansible seeds `/var/lib/adguardhome/AdGuardHome.yaml` once (upstreams, admin
  user, ports). AdGuard Home owns that file afterwards, so change settings, blocklists
  and rewrites in the web UI. A rebuilt VM starts again from the seed.
- Password: the seed only takes a bcrypt hash, e.g. `htpasswd -nbBC 10 "" <password> | tr -d ':\n'`.
  Changing the secret does not change the password of a running instance.
- Upgrade: bump `adguard_home_version`; the built-in updater is off
- DHCP: the Ziggo modem refuses a private address as DNS server, so AdGuard Home is meant
  to be the LAN's DHCP server and hand out itself as DNS server. Ansible configures it
  (pool `.20`-`.180`, gateway `.1`, 24 h leases, clients resolve as `<hostname>.lan`;
  `adguard_home_dhcp_*` in the role defaults) but never switches it on: a deploy must not
  start a second DHCP server next to the modem's. Switch it by hand, at the same time:
  modem DHCP off, then Settings → DHCP settings → Enable DHCP server in the web UI. A
  rebuilt VM starts with DHCP off again. Change the pool in the role defaults, not the web
  UI, a deploy writes it back. Static leases are set in the web UI
- Single instance: when the VM is down, LAN clients lose DNS and new devices get no
  address. Turn the modem's DHCP server back on to fall back

### Reverse proxy

`reverse-proxy` (`.207`, id 907, on `proxmox-prodesk`) runs Caddy for
`https://<service>.homelab.rutgerpronk.com`: one wildcard certificate from Let's Encrypt
through a Cloudflare DNS-01 challenge, so nothing is exposed to the internet. Only SSH,
80 (redirects to https) and 443 are reachable.

- Add a service: an entry in `caddy_routes` in the role defaults. The AdGuard wildcard
  rewrite already points every name here, so no DNS change is needed
- Upstreams with self-signed certificates (Proxmox) set `insecure_tls`
- Upgrade: bump `caddy_version`. The binary comes from caddyserver.com's download service
  with the `caddy-dns/cloudflare` module; it builds on request and takes a few minutes
- Some apps must trust the proxy before they accept proxied requests:
  - Home Assistant: in `configuration.yaml`, `http:` with `use_x_forwarded_for: true` and
    `trusted_proxies: [192.168.178.207]`
  - OpenClaw: `https://openclaw.homelab.rutgerpronk.com` in
    `gateway.controlUi.allowedOrigins` and `192.168.178.207` in `gateway.trustedProxies`
- Grafana goes through Traefik with `Host: grafana.rutgerpronk.com`, so it still redirects
  to that public name in places, until it gets its own internal route

### Known limits

- cloud-init only runs on first boot; changes to it only reach new VMs (SSH keys are
  the exception, Ansible keeps those in sync)
- No backups yet; set up vzdump or PBS before relying on the data disk alone

### k3s

`k3s-1` (`.201`, id 911) is the server, `k3s-2` (`.202`, id 912) joins it as an agent
with `K3S_TOKEN`. Same version as the hand-built cluster (`k3s_version` in the role
defaults, bump to upgrade), with ServiceLB disabled for MetalLB. Workloads come from
kubernetes-infrastructure; PVCs (`local-path`) live on the root disk, so a rebuild
loses them.

The cluster CAs come from `K3S_CA_BUNDLE` and are put in place before k3s first starts,
so a rebuilt server signs with the same CAs: existing admin kubeconfigs keep working,
at `https://192.168.178.201:6443`, and so does the read-only kubeconfig from
kubernetes-infrastructure `4-rbac` (a client certificate from the same client CA). Service
account tokens do not survive a rebuild, they belong to objects in the old cluster;
kubernetes-infrastructure recreates them.
The secret holds the CA private keys, which give full admin access to the cluster.

Export the CAs from the running server, for example to restore the secret. Pack them
first and upload in a second step, so a sudo password prompt cannot end up in the secret
(the hand-built K3s-1 used user `k3s` instead of `debian`):

```bash
ssh -t debian@192.168.178.201 'sudo sh -c "cd /var/lib/rancher/k3s/server/tls && tar -czf ~debian/k3s-ca.tar.gz *-ca.crt *-ca.key service*.key \$(ls -d etcd/*-ca.* 2>/dev/null) && chown debian ~debian/k3s-ca.tar.gz"'
ssh debian@192.168.178.201 'tar -tzf k3s-ca.tar.gz'   # expect server-ca.key, client-ca.key, ...
ssh debian@192.168.178.201 'base64 -w0 k3s-ca.tar.gz && rm k3s-ca.tar.gz' \
  | gh secret set K3S_CA_BUNDLE -R Rutger505-Org/homelab-infrastructure
```

The role refuses to install the server without it, so a failed export cannot quietly
start a cluster with new CAs.

### Tailscale router

`tailscale` (`.213`, id 913) advertises `192.168.178.0/24` as `tag:homelab`.
It joins with an OAuth client secret instead of an auth key, which never expires, so
a rebuilt VM can always rejoin. The tailnet policy already owns `tag:homelab` and
auto-approves the route for it. One-time setup:

- create an OAuth client with the `auth_keys` write scope and `tag:homelab`,
  store its secret as `TAILSCALE_ROUTER_OAUTH_SECRET`

CI reaches the LAN through this router: when it is down, run locally.

### OpenClaw

`openclaw` (`.210`, id 910) runs Arch from the Arch cloud image, with `openclaw` as
login user. Ansible installs the packages, enables lingering, writes the
GitHub key, `~/.openclaw/.env` and `~/.kube/readonly.kubeconfig`, sets up the
openclaw-config checkout with its sync timer, clones dev-env and installs OpenClaw.

Not automated:

- dev-env's `install.sh` is interactive, run it once by hand
- `.env` is only written when missing, the sync adds secrets to it on the VM. Update
  `OPENCLAW_ENV` when it changes, or a rebuild comes up without them
- State outside the config repo (sessions, memory, channel credentials in
  `~/.openclaw`) is not backed up. Copy it over by hand

The Gateway service is only installed with `openclaw_gateway_enabled: true`. Turn it off
before running a second Gateway with the same state: two Gateways with the same channel
credentials both answer.

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

## Internal DNS

`internal-dns/` (OpenTofu, `gmichels/adguard` provider) manages DNS rewrites in AdGuard Home.
`*.homelab.rutgerpronk.com` resolves to the reverse proxy for every client that uses
AdGuard Home as DNS server; new services only need a route there, not a DNS change.

- Applied on every push to `internal-dns/` and after every successful homelab deploy, so a
  rebuilt AdGuard VM gets its rewrites back. Rewrites added by hand in the web UI are left alone
- Own state key in the same R2 bucket and passphrase

One-time setup:
- GitHub secret `ADGUARD_ADMIN_PASSWORD`: the AdGuard Home web UI password (plain text)
- Tailnet policy: allow `tag:ci-homelab` to reach `192.168.178.205:80`
