# Proxmox as code (prototype)

Turns the manual "Tailscale" and "Kubernetes" sections of the top-level README
into one `tofu apply`: three Debian VMs, static addresses, joined to the tailnet,
with k3s installed as a two-node cluster. No SSH step at the end.

This is a **prototype**. It has never been applied against the real hypervisor —
see "Status" at the bottom for what that means and how to try it safely.

## What it demonstrates

The interesting claim was not "Terraform can create a VM". It was whether the
*service inside* the VM can be declared too. It can:

- **Base image** downloaded onto the datastore by Proxmox itself, so there is no
  "upload the ISO" or "build a template first" step. VM disks clone from it.
- **cloud-init** carries users, SSH keys, packages and first-boot commands.
- **Tailscale** joins the tailnet with a pre-authorised key that OpenTofu mints
  through the Tailscale provider. Nobody logs in interactively. The router VM
  advertises `192.168.178.0/24`, which is what makes MetalLB addresses reachable
  remotely without publishing anything.
- **K3s** installs as server + agent with a generated shared token, with
  ServiceLB disabled so it does not fight MetalLB.

So both halves of the earlier question are answered in one place, and Ansible is
not needed for this much. It earns its place later, when configuration drifts
after first boot — cloud-init runs once, Ansible converges continuously.

## Why the state is not in Kubernetes

Everything in `kubernetes-infrastructure` uses `backend "kubernetes"`. Correct
there, wrong here: the k3s nodes are VMs managed by *this* module, so keeping
this state in k3s means the cluster's substrate is described by state living
inside the cluster. The day k3s is broken is the day you need this state, and it
would be unreachable.

State must sit lower in the dependency stack than what it manages, so this layer
uses a hosted backend (`cloud {}` in `versions.tf`). Nothing in the homelab needs
to be up to read it, and locking comes for free. MinIO was the tempting
alternative, but MinIO is a pod in k3s — same inversion, one step removed.

## Prerequisites

**1. Proxmox API token.** A dedicated user, never root:

```
Datacenter -> Permissions -> Users -> Add: terraform@pve
Datacenter -> Permissions -> API Tokens -> Add: terraform@pve!terraform
Datacenter -> Permissions -> Add -> API Token Permission:
  path /  role PVEAdmin  propagate on
```

`PVEAdmin` is broad because creating VMs is inherently broad. Scope it to a pool
(`/pool/lab`) to get a token that structurally cannot touch anything outside it.

**2. Snippets enabled.** cloud-init user data is uploaded to a snippets
datastore, and `local` does not have that content type on by default:

```
Datacenter -> Storage -> local -> Edit -> Content: add "Snippets"
```

**3. SSH to the Proxmox host.** The API has no endpoint for writing snippets, so
the provider uploads them over SSH. This is the one part that needs more than an
API token, and the honest weak point of the design.

**4. Tailscale OAuth client** with the `auth_keys` scope, from the admin console,
plus a `tag:homelab` entry in the tailnet policy owned by that client.

## Running it

```bash
export TF_CLOUD_ORGANIZATION=<org>
export PROXMOX_VE_ENDPOINT='https://192.168.178.200:8006/'
export PROXMOX_VE_API_TOKEN='terraform@pve!terraform=<uuid>'
export PROXMOX_VE_SSH_USERNAME=root

tofu init
tofu plan
```

Variables without defaults: `proxmox_endpoint`, `ssh_public_keys`,
`tailscale_oauth_client_id`, `tailscale_oauth_client_secret`.

Read the plan before applying. `3 to add, 0 to destroy` is what a first run
should say; any non-zero destroy count on a first run means the addresses or VM
ids collide with something that already exists.

## Try it without risking the real thing

The current VMs at `.201`–`.203` were built by hand, so OpenTofu does not know
about them and an apply with those ids will collide.

```hcl
tailscale_vm = { vm_id = 903, ipv4_address = "192.168.178.213/24" }
k3s_server   = { vm_id = 901, ipv4_address = "192.168.178.211/24" }
k3s_agent    = { vm_id = 902, ipv4_address = "192.168.178.212/24" }
```

That builds a parallel throwaway cluster, proves the whole path end to end, and
`tofu destroy` removes it. Adopting the real VMs afterwards is `tofu import` per
VM — worth doing only once the prototype has actually worked twice.

## Verifying

```bash
tailscale status                      # three new nodes
ssh debian@192.168.178.211 sudo kubectl get nodes   # server + agent, both Ready
```

If a VM boots but nothing is installed, the cloud-init log is the place to look:
`sudo cat /var/log/cloud-init-output.log`. A VM Proxmox reports without an IP
usually means the guest agent never started, which also breaks clean shutdowns.

## Known rough edges

- **Not applied yet.** Written against the bpg provider's schema and reviewed,
  not run. Treat the first plan as the real review.
- **cloud-init runs once.** Changing `extra_runcmd` does not reconfigure a
  running VM; it only affects a rebuilt one. This is the boundary where Ansible
  starts being worth it.
- **The k3s token lives in state.** Another reason the backend matters.
- **Agent/server race** is handled by a retry loop in the guest rather than real
  orchestration. Fine for two nodes, not a pattern to scale.
- **No backups here.** Automated VM creation is only comfortable once vzdump or
  PBS makes a bad apply cost twenty minutes instead of an evening.
