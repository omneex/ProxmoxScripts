#!/bin/bash
#
# UpdateAllLXC.sh
#
# A script to apply package updates to all Linux containers (LXC) on every host in a Proxmox cluster.
#
# Usage:
#   ./UpdateAllLXC.sh
#
# Description:
#   This script enumerates all nodes in the Proxmox cluster, then for each node, retrieves a list
#   of LXC containers and applies apt-get updates to each container. Requires root privileges and
#   SSH access (without password or key prompt) between the nodes.
#

set -e

# --- Preliminary Checks -----------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root (sudo)."
  exit 1
fi

if ! command -v pvecm &>/dev/null; then
  echo "Error: 'pvecm' not found. Are you sure this is a Proxmox node?"
  exit 2
fi

# --- Main Script Logic -----------------------------------------------------
echo "Gathering node list from cluster..."
NODES=$(pvecm nodes | tail -n +2 | awk '{print $2}')  # Skip header line, get 'Name' field

for node in $NODES; do
  echo "Processing LXC containers on node: $node"
  CONTAINERS=$(ssh "$node" "pct list | tail -n +2 | awk '{print \$1}'" 2>/dev/null)

  if [[ -z "$CONTAINERS" ]]; then
    echo "  No LXC containers found on $node"
    continue
  fi

  for ctid in $CONTAINERS; do
    echo "  Updating container CTID: $ctid"
    ssh "$node" "pct exec $ctid -- apt-get update && apt-get upgrade -y"
    echo "    Update complete for CTID: $ctid"
  done
done

echo "All LXC containers have been updated across the cluster."
