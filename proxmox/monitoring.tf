# Pulse (kubernetes-infrastructure 8-pulse) reads each VM's /proc/meminfo
# through the guest agent, for memory use without page cache. It shares the
# read-only monitoring token with pve-exporter: prometheus@pve!monitoring
# (privsep off, so the token has the user's privileges). The user, its token
# and its PVEAuditor ACL on / were made by hand; see kubernetes-infrastructure's
# 7-monitoring README.
#
# VM.GuestAgent.FileRead can read any file inside a guest, so this widens what
# that token can see.
resource "proxmox_virtual_environment_role" "guest_agent_read" {
  role_id = "GuestAgentRead"
  privileges = [
    "VM.GuestAgent.Audit",
    "VM.GuestAgent.FileRead",
  ]
}

resource "proxmox_acl" "monitoring_guest_agent_read" {
  user_id   = "prometheus@pve"
  role_id   = proxmox_virtual_environment_role.guest_agent_read.role_id
  path      = "/vms"
  propagate = true
}
