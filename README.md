# homelab-infrastructure

Two Proxmox nodes running Debian VMs (OpenClaw: Arch), all as code. This README only covers what the code can't tell you; for everything else read the files below.

## Where things live

- `ansible/inventory.yml`: every VM (address, id, node, size) and the LAN/IPv6 address plan. Source of truth for OpenTofu and Ansible.
- `proxmox/` (OpenTofu): creates the VMs from cloud images. cloud-init only sets the login user, SSH keys and guest agent. Also the guest agent privileges of the shared monitoring token (`monitoring.tf`).
- `ansible/playbook.yml`, `ansible/roles/<role>/`: configures each VM. Versions and settings in the role's `defaults/`.
- `ansible/proxmox.yml`, `ansible/proxmox-inventory.yml`: the Proxmox nodes themselves (no-nag patch, tag colors), over root SSH. Separate inventory so OpenTofu never sees the nodes.
- `dns/` (OpenTofu): every Cloudflare record of `rutgerpronk.com` and `rutgerpronk.nl`. Dashboard edits are drift and get reverted.
- `internal-dns/` (OpenTofu): AdGuard rewrites (`homelab.rutgerpronk.com` and `*.homelab.rutgerpronk.com` → reverse proxy) and tailnet split DNS. Rewrites added in the web UI are left alone.
- `.github/workflows/`: `deploy.yaml`, `dns.yaml`, `internal-dns.yaml`, and the secrets/vars they need. `.github/deploy-services.yaml` maps changed paths to services.

OpenTofu state is in the R2 bucket `homelab-tofu-state` (one key per root), encrypted with `TOFU_STATE_PASSPHRASE` (Bitwarden). Not in k3s, so it survives the cluster.

## CI

- PR: `tofu plan` and `ansible-playbook --check --diff` against the live VMs (VMs the PR adds are skipped). Push to main: apply. A manual run deploys every service, e.g. to undo manual changes.
- One Ansible job per service, limited to its inventory group. A `shared` path deploys all VM services.
- Check mode skips commands, so read-only probes need `check_mode: false`, otherwise later tasks report fake changes.
- CI joins the tailnet as `tag:ci-homelab` and reaches the LAN through the `tailscale` subnet router. Router down: run locally.
- `internal-dns` also applies after every successful deploy, so a rebuilt AdGuard VM gets its rewrites back.

## Common changes

- Add a VM: host in the inventory (all size fields required, no defaults), a play in `playbook.yml`, the group in `deploy-services.yaml`. Optional `os: arch`, `ansible_user`.
- Rebuild a VM: `prevent_destroy` in `proxmox/modules/vm/main.tf` fails the run; remove it on purpose.
- Changing `ansible_host`: new cloud-init instance id, so new address and new SSH host keys on next boot.
- SSH keys: `ssh_authorized_keys` in the inventory is the exact `authorized_keys` on every VM; keep `homelab-ci`. Per host extras: `ssh_extra_authorized_keys`.
- New `<service>.homelab.rutgerpronk.com`: an entry in `caddy_routes`, no DNS change; it also shows up on the `homelab.rutgerpronk.com` landing page. Some apps must trust the proxy (`192.168.178.207`):
  - Home Assistant: done by the role, in the confirmed (`stable`) slot of `.storage/http` (YAML `http:` is ignored since 2026.8); from the `reverse_proxy` group
  - OpenClaw: URL in `gateway.controlUi.allowedOrigins`, proxy in `gateway.trustedProxies`
- Upgrade a service: bump its `*_version` in the role defaults.
- Use homelab names from a device: Tailscale with DNS and routes accepted (`tailscale up --accept-dns --accept-routes`).

## Manual and not automated

- **No backups** (no vzdump/PBS). k3s PVCs live on the root disk and are lost on rebuild.
- cloud-init only runs on first boot; changes reach new VMs only (SSH keys excepted).
- AdGuard Home: the config is seeded once, then owned by the web UI, except the `dhcp` settings. DHCP is never switched on by a deploy: turn the modem's DHCP off and enable it in the web UI by hand (a rebuilt VM starts with it off). If the VM is down, turn modem DHCP back on. The modem's IPv6 DNS field must be `2001:1c07:504:1d00::53`. Changing the password secret does not change a running instance.
- Home Assistant: onboarding creates the owner; add the MQTT integration with broker `localhost`. Proxy trust in the UI (HTTP server) gets overwritten by the role; other HTTP server settings stay. The role fails on an unknown `.storage/http` version after an HA upgrade: check the format, bump the expected version.
- OpenClaw VM: run dev-env's `install.sh` by hand. `.env` is only written when missing, so keep `OPENCLAW_ENV` up to date. State outside the config repo (sessions, memory, channel credentials) is not backed up. Set `openclaw_gateway_enabled: false` before running a second Gateway with the same state, or both answer.
- Grafana is LAN only: Caddy is its only route in, to its MetalLB address `.231`.
- Proxmox no-nag: the run fails when a widget toolkit update breaks the patch. Tag style changes made in the UI get overwritten.

### k3s CA bundle

`K3S_CA_BUNDLE` holds the cluster CAs (including private keys: full cluster admin), so a rebuilt cluster keeps working with existing kubeconfigs. The role refuses to install without it. Export it from the running server (pack first, so a sudo prompt can't end up in the secret):

```bash
ssh -t debian@192.168.178.201 'sudo sh -c "cd /var/lib/rancher/k3s/server/tls && tar -czf ~debian/k3s-ca.tar.gz *-ca.crt *-ca.key service*.key \$(ls -d etcd/*-ca.* 2>/dev/null) && chown debian ~debian/k3s-ca.tar.gz"'
ssh debian@192.168.178.201 'tar -tzf k3s-ca.tar.gz'   # expect server-ca.key, client-ca.key, ...
ssh debian@192.168.178.201 'base64 -w0 k3s-ca.tar.gz && rm k3s-ca.tar.gz' \
  | gh secret set K3S_CA_BUNDLE -R Rutger505-Org/homelab-infrastructure
```

## One-time setup

- Proxmox API token, on one node:
  ```bash
  pveum user add terraform@pve --comment "OpenTofu"
  pveum acl modify / --users terraform@pve --roles Administrator
  pveum user token add terraform@pve opentofu --privsep 0   # secret: PROXMOX_VE_API_TOKEN=terraform@pve!opentofu=<secret>
  ```
- Enable `Snippets` and `Import` content on the `local` storage.
- `ssh-keygen -t ed25519 -f homelab-ci -C homelab-ci`; public key in `/root/.ssh/authorized_keys` on both nodes (OpenTofu uploads snippets over SSH), private key as `HOMELAB_SSH_PRIVATE_KEY`.
- R2 bucket `homelab-tofu-state` with an Object Read & Write token; state passphrase of 16+ characters.
- Tailscale: `tag:ci-homelab` in `tagOwners`. OAuth clients: CI (`auth_keys` write, `tag:ci-homelab`), router (`auth_keys` write, `tag:homelab`, never expires so a rebuild can rejoin), DNS (`dns` write). ACLs: `tag:ci-homelab` → `192.168.178.0/24` ports 22, 8006 and `192.168.178.205:80`; own devices → `192.168.178.205:53`, `192.168.178.207:443`.
- Cloudflare token with `Zone:DNS:Edit`, `Zone:Single Redirect:Edit`, `Zone:Zone:Read` on both zones → `CLOUDFLARE_DNS_API_TOKEN` (also the reverse proxy's DNS-01 challenge).
- Secrets with a non-obvious value: `K3S_TOKEN` (`openssl rand -hex 32`), `ADGUARD_ADMIN_PASSWORD_HASH` (`htpasswd -nbBC 10 "" <password> | tr -d ':\n'`, plain text in `ADGUARD_ADMIN_PASSWORD`), `OPENCLAW_READONLY_KUBECONFIG` (kubernetes-infrastructure `4-rbac`), `OPENCLAW_ENV` (`~/.openclaw/.env`).

## Running locally

When CI can't reach the LAN. From the LAN, with your SSH key in the agent and on the Proxmox nodes: export the `env:` blocks of `deploy.yaml` (R2 keys as `AWS_*`, `TF_VAR_state_passphrase`, `PROXMOX_VE_*`, the service secrets under the same names, `CLOUDFLARE_API_TOKEN`), then:

```bash
tofu -chdir=proxmox init && tofu -chdir=proxmox apply
cd ansible && ansible-playbook playbook.yml   # nodes: ansible-playbook -i proxmox-inventory.yml proxmox.yml
```
