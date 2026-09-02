# Setting up home lab

Notes for setting up the home lab (again..).

All VMs run Debian. The Openclaw VM is the exception and runs Arch.

## Proxmox

1. Install Proxmox on both servers
2. Initialize cluster
3. Add one server as slave
4. Upload the Debian server ISO
5. Set static ip to 200. For other installs move to 199, 198, etc.

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
6. Install K3s on 202 as slave (look at official docs)
7. Disable the bundled ServiceLB (see Networking below) before deploying anything
8. Copy kubeconfig to the Bitwarden entry
9. Configure the GitHub org with the new kubeconfig

## Networking

MetalLB does all LoadBalancer routing. Every service gets a fixed address from
the pool `192.168.178.230-250`, defined in `kubernetes-infrastructure/3-metallb-config`.

### Address allocation

| IP  | Service          | Where it is set                                  |
| --- | ---------------- | ------------------------------------------------ |
| 230 | Traefik ingress  | `TRAEFIK_IP` (kubernetes-infrastructure)          |
| 231 | Pi-hole DNS      | `PIHOLE_DNS_IP` (kubernetes-infrastructure)       |
| 232 | Pi-hole web UI   | `PIHOLE_WEB_IP` (kubernetes-infrastructure)       |
| 233 | LiveKit media    | `load_balancer_ip` in `relay/deploy/main.tf`      |

The pool runs with `autoAssign = false`, so a service only gets an address if it
asks for one explicitly. A service without `loadBalancerIP` stays on `<none>`.

Two services may only share an address if **both** carry an identical
`metallb.universe.tf/allow-shared-ip` annotation. Otherwise the first claimant
wins and the other is left without an IP.

### Disable k3s ServiceLB

k3s ships its own LoadBalancer implementation (ServiceLB / klipper-lb) that
ignores requested IPs and instead binds the service port as a **hostPort on
every node**, publishing the node IPs as the external address. Alongside MetalLB
it is redundant and actively harmful: it claims host ports cluster-wide, so only
one service can own port 80/443/53 per node.

Run this on **both** k3s servers (201 and 202):

```bash
sudo tee -a /etc/rancher/k3s/config.yaml <<'EOF'
disable:
  - servicelb
EOF

sudo systemctl restart k3s

# no svclb-* daemonsets should remain
kubectl get ds -n kube-system | grep svclb
```

Before restarting, make sure every LoadBalancer service has an explicit IP,
otherwise it loses external reachability once ServiceLB is gone:

```bash
kubectl get svc -A --field-selector spec.type=LoadBalancer \
  -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,LBIP:.spec.loadBalancerIP,EXT:.status.loadBalancer.ingress[*].ip'
```

### Router port forwarding

Forward to the MetalLB address, never to a node IP. Forwarding to a node IP only
works while ServiceLB holds that host port, and breaks the moment it is disabled.

| External port | Forward to        | Service       |
| ------------- | ----------------- | ------------- |
| 80, 443 TCP   | 192.168.178.230   | Traefik       |
| 7881, 7882    | 192.168.178.233   | LiveKit media |

Verify ingress answers on the MetalLB address directly:

```bash
curl -kI https://192.168.178.230 -H 'Host: dijker.rutgerpronk.com'
```

### Node DNS

Never point a k3s node's resolver at Pi-hole (192.168.178.231). The node needs
working DNS to pull the Pi-hole image, so Pi-hole cannot be its own resolver;
the node would deadlock on boot. Keep the nodes on public resolvers and let
clients use Pi-hole.

Also set a **secondary DNS** on the router (for example `1.1.1.1`). Pi-hole is a
single replica pinned to one node by its ReadWriteOnce volume, so LAN DNS stops
when that node or pod is down.

### Troubleshooting: node cannot resolve anything

Symptom: `curl` and `getent` fail with `Temporary failure in name resolution`,
while `dig @127.0.0.53` still answers, and image pulls fail with
`lookup registry-1.docker.io: Try again`.

Cause seen in practice: ServiceLB had claimed hostPort 53 for a Pi-hole
LoadBalancer service that had no ready endpoints, so kube-proxy answered
port 53 with `REJECT --reject-with icmp-port-unreachable`.

```bash
# confirm: is something serving the port via servicelb?
kubectl get ds -n kube-system | grep svclb
sudo iptables-save | grep ':53'

# temporary proof (rules return on reboot or k3s restart)
sudo nft flush ruleset
dig linux.org +short
```

The fix is disabling ServiceLB as described above, not editing firewall rules.
Ubuntu's stock `/etc/nftables.conf` has empty chains with a default `accept`
policy and blocks nothing; the rules involved are installed at runtime by k3s.

## Openclaw

1. Create the VM (Arch). Enable the QEMU guest agent in the Proxmox panel, at creation or later under VM, Options, QEMU Guest Agent, Enable
2. Create Bitwarden entries for the password
3. Configure authorized keys
4. Configure 204 as static IP address
5. Install openclaw
