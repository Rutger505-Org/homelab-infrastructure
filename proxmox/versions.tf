terraform {
  required_version = ">= 1.6"

  # State deliberately does NOT live in the k3s cluster.
  #
  # Every module in kubernetes-infrastructure uses `backend "kubernetes"`, which
  # is the right call there: the state for cluster resources lives in the
  # cluster those resources are in, and nothing depends on it.
  #
  # This layer is different. The k3s nodes are VMs managed *here*, so storing
  # this state in k3s would mean the cluster's own substrate is described by
  # state living inside the cluster. The day the cluster is broken is exactly
  # the day you need this state, and it would be unreachable.
  #
  # State must live lower in the dependency stack than what it manages, so it
  # goes to a hosted backend: nothing in the homelab has to be up to read it,
  # and state locking is included.
  #
  # Configure with TF_CLOUD_ORGANIZATION and TF_WORKSPACE, or fill in below.
  cloud {
    workspaces {
      name = "homelab-proxmox"
    }
  }

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.113"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.29"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
