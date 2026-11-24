# homelab-infrastructure

Proxmox VMs/LXCs (OpenTofu), guest config (Ansible), Cloudflare DNS, AdGuard rewrites, tailnet policy. **Read README.md first**: layout, CI, common changes, manual steps, secrets. This file = rules + risks.

## Rules
- Branch from `origin/main`, PR, squash-merge. PR runs `tofu plan` + `ansible-playbook --check --diff`; merge = apply (path filters per workflow, `.github/deploy-services.yaml` maps paths → services).
- **Every PR says which guests restart.**
- Inventory (`ansible/inventory.yml`) is the source of truth for guests: `guest_type: lxc` = LXC, else VM; `proxmox_node`.
- Guest DNS is static from tofu (`local.nameservers` in `proxmox/main.tf`): guests → both AdGuards, AdGuard → modem. **Never add the modem as fallback** (resolved switches to it, `*.homelab` then resolves to the public IP).

## Network SPOFs
- All home DNS + DHCP = `adguard-1` (prodesk) + `adguard-2` (lade). Both down = house offline-ish.
- CI + remote access reach the LAN only via subnet routers `tailscale` (lade) + `tailscale-2` (prodesk). Both down = run locally (README).
- One Proxmox node down = one of each pair gone. Never take down both nodes, or both of a pair, at once.

## Blast radius of an apply
- tofu applies in parallel: a change in `proxmox/modules/vm` or `modules/lxc` hits **every guest of that type at once**.
- `initialization` change (DNS, IP, …) reboots: VMs (cloud-init rebuild + bpg `reboot_after_update`), LXCs always. The plan doesn't show reboots; check the bpg update code.
- VM hardware change (`serial_device`, cpu, …): bpg reboots via the Proxmox reboot API (shutdown + start).
- **Never reboot a tailscale router in the same apply as other guests**: CI's connection resets mid-apply (#116).
- Failed apply after the config PUT: state already has the new values, rerun says "No changes", but the cloud-init rebuild/reboot never happened. Fix: Proxmox UI Reboot of those VMs (full stop/start regenerates cloud-init; reboot inside the guest doesn't).
- Both k3s nodes rebooting = every k8s site down for minutes.
- Change restarting both of a pair (adguard, tailscale, k3s): split per node over two PRs/applies, or let Rutger pick the moment.
