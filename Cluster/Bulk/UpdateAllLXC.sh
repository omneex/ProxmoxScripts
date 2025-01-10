#!/bin/bash
#
# UpdateAllLXC.sh
#
# A script to apply package updates to all Linux containers (LXC) on every host
# in a Proxmox cluster. Requires root privileges and passwordless SSH between nodes.
#
# Usage:
#   ./UpdateAllLXC.sh
#
# Example:
#   ./UpdateAllLXC.sh
#
# Description:
#   1. Checks if this script is run as root (check_root).
#   2. Verifies this node is a Proxmox node (check_proxmox).
#   3. Installs 'ssh' if missing (install_or_prompt "ssh").
#   4. Ensures the node is part of a Proxmox cluster (check_cluster_membership).
#   5. Finds the local node IP and remote node IPs.
#   6. Iterates over all nodes (local + remote), enumerates their LXC containers,
#      and applies package updates inside each container.
#   7. At script exit, prompts to keep or remove newly installed packages
#      (prompt_keep_installed_packages).
#

###############################################################################
# Preliminary Checks via Utilities
###############################################################################
check_root
check_proxmox
check_cluster_membership

###############################################################################
# Gather Node IP Addresses
###############################################################################
LOCAL_NODE_IP="$(hostname -I | awk '{print $1}')"

# Gather remote node IPs (excludes the local node)
readarray -t REMOTE_NODE_IPS < <( get_remote_node_ips )

# Combine local + remote IPs
ALL_NODE_IPS=("$LOCAL_NODE_IP" "${REMOTE_NODE_IPS[@]}")

###############################################################################
# Main Script Logic
###############################################################################
echo "Updating LXC containers on all nodes in the cluster..."

# Iterate over all node IPs
for nodeIp in "${ALL_NODE_IPS[@]}"; do
  echo "--------------------------------------------------"
  echo "Processing LXC containers on node: \"${nodeIp}\""

  # 'pct list' header is removed by tail -n +2
  containers="$(ssh "root@${nodeIp}" "pct list | tail -n +2 | awk '{print \$1}'" 2>/dev/null)"

  if [[ -z "$containers" ]]; then
    echo "  No LXC containers found on \"${nodeIp}\""
    continue
  fi

  # Update each container
  while read -r containerId; do
    [[ -z "$containerId" ]] && continue
    echo "  Updating container CTID: \"${containerId}\" on node \"${nodeIp}\"..."
    if ssh "root@${nodeIp}" "pct exec ${containerId} -- apt-get update && apt-get upgrade -y"; then
      echo "    Update complete for CTID: \"${containerId}\""
    else
      echo "    Update failed for CTID: \"${containerId}\""
    fi
  done <<< "$containers"
done

echo "All LXC containers have been updated across the cluster."
