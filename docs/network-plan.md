# Network segmentation plan

Status: **plan, nothing built yet.** Replaces the closed "move the LAN to 192.168.1.0/24" PRs.

## Goal and limits

Separate the homelab from the house network, and public-facing services from the rest, without new hardware. An OPNsense VM routes and firewalls between internal Proxmox networks; the house network stays on the Ziggo modem as it is.

What this does **not** give (needs hardware: managed switch, mini PC, VLAN-capable access points):
- Separate Wi-Fi for smart devices vs. own devices. Guests: use the modem's guest Wi-Fi.
- Protection of the Proxmox nodes from the house network: they are physical and stay on `192.168.178.0/24`.
- Settings that survive a modem reset: port forwards still live on the modem.

## Layout

- **House** `192.168.178.0/24` (modem, unchanged): PCs, phones, smart devices, Proxmox nodes `.199`/`.200`, OPNsense WAN.
- **Homelab** `10.0.20.0/24`: AdGuard, Caddy, k3s, SeaweedFS, OpenClaw, Tailscale router. VMs keep their last octet (`192.168.178.214` → `10.0.20.214`).
- **Public** `10.0.30.0/24`: what the internet reaches (Traefik / public k3s workloads). Phase 5.

Both internal networks are Proxmox SDN VNets in a VXLAN zone, so they span `proxmox-lade` and `proxmox-prodesk` over the existing network without a managed switch. VXLAN costs 50 bytes: VM MTU 1450 on these VNets.

### OPNsense VM

- On `proxmox-lade` (16 GB), 2 cores, 2 GB RAM, ~16 GB disk.
- NICs: WAN on `vmbr0` (`192.168.178.198`, gateway `.1`), one per VNet (`10.0.20.1`, `10.0.30.1`).
- Virtual IPs on WAN, kept from today so nothing changes for house devices or the modem's DNS setting:
  - `192.168.178.205` → AdGuard `10.0.20.205` (53/udp+tcp, web UI 80)
  - `192.168.178.207` → Caddy `10.0.20.207` (443)
- Outbound NAT for both VNets to WAN.
- Single point of failure for the homelab only; the house keeps internet when it is down.

## Firewall rules (default deny between segments)

- House → Homelab: only via the virtual IPs above (DNS, Caddy). Proxmox web UI stays on the house network.
- Homelab → House: Proxmox API/SSH (`.199`/`.200`: 8006, 22) for CI and tofu; Home Assistant if it stays on the house network.
- Homelab → internet: allowed.
- Public → anything internal: denied; only replies to established connections. Public → internet: allowed.
- Internet → Public: modem forwards 80/443 to OPNsense WAN `192.168.178.198`, OPNsense forwards to Traefik.
- Homelab → Public: Caddy to Traefik/Grafana-style upstreams as needed.

## CI and remote access

CI reaches the LAN through the Tailscale subnet router. It moves into Homelab and advertises `10.0.20.0/24` (and `10.0.30.0/24`) plus `192.168.178.0/24` for the Proxmox nodes, which it reaches through OPNsense. Tailnet ACLs and autoApprovers get the new ranges. Tailscale devices with `--accept-routes` reach the homelab directly, at home and away.

## Phases

Every phase is its own PR and leaves a working homelab.

1. **OPNsense + SDN, nothing moved.**
   - `proxmox/`: SDN VXLAN zone, VNets `homelab`/`public`, OPNsense VM (installed from ISO, not cloud-init).
   - OPNsense config by hand first; config-as-code (OPNsense API / `ansibleguy.opnsense`) decided after it works.
   - Inventory: per-host `network` (`house` | `homelab` | `public`); tofu picks bridge, address and gateway from it.
2. **Tailscale router into Homelab** (CI path). Tailnet policy first, keep the old route until verified.
3. **Move VMs one at a time**, verifying each: SeaweedFS → OpenClaw → k3s (both nodes together; re-export kubeconfigs, update kubernetes-infrastructure `SEAWEEDFS_IP` etc.) → AdGuard + Caddy last, together with the WAN virtual IPs.
4. **Public traffic via OPNsense**: modem port forwards (80, 443, 25565) to OPNsense, OPNsense to Traefik.
5. **Public segment.** Open decision, see below.

## Open decisions

- **Home Assistant**: device discovery (mDNS, SSDP, Chromecast, ...) does not cross a router. Proposal: keep it on the house network (where the smart devices are) until there are IoT VLANs; Caddy reaches it through the Homelab → House rule.
- **Public k3s**: a k3s node in Public still needs the API server (6443), kubelet (10250) and flannel (8472/udp) to the Homelab nodes, which weakens the separation. Options: (a) separate small public cluster, (b) public node with taints + NetworkPolicies, accepting the holes, (c) keep k3s in Homelab and only put Traefik's exposure behind OPNsense (phase 4). Proposal: start with (c), revisit with real public workloads.
- **MetalLB**: L2 mode only announces on the node's own network, so the pool moves to `10.0.20.230-250` with k3s; house devices reach those through Caddy, as already happens for Grafana and Pulse.
- **OPNsense config as code** (see phase 1).
- **Hardware later**: OPNsense moves to a mini PC with the same config; the VNets become real VLANs on a managed switch; IoT/Trusted/Guest Wi-Fi with VLAN access points.
