#!/bin/bash
#
# UpgradeAllServers.sh
#
# A script to update all servers in the Proxmox cluster.
#
# Usage:
#   ./UpgradeAllServers.sh
#
# This script automatically loops through all nodes in the Proxmox cluster and updates them
# without any user prompts for a server list. The script must be run as root or with sudo.
#
# Example:
#   ./UpgradeAllServers.sh
#

set -e

# --- Preliminary Checks -----------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root (sudo)."
  exit 1
fi

if ! command -v pvecm &>/dev/null; then
  echo "Error: 'pvecm' command not found. Are you sure this is a Proxmox node?"
  exit 2
fi

if ! command -v ssh &>/dev/null; then
  echo "Error: 'ssh' command not found. Please install SSH or verify it's on your system."
  exit 3
fi

# --- Gather Node List -------------------------------------------------------
# pvecm nodes output example:
#   Membership information
#   ----------------------
#       Nodeid      Votes Name
#            1          1 pve01 (local)
#            2          1 pve02
#
# Using awk to skip header lines and pick out the second column (Name):
NODES=$(pvecm nodes | awk 'NR>1 && $2 !~ /Quorate/ {print $2}')

# --- Update Each Node -------------------------------------------------------
for node in $NODES; do
  echo "Updating node: $node"

  # If the node name matches the current hostname, update locally
  if [[ "$node" == "$(hostname)" ]]; then
    apt-get update
    apt-get -y dist-upgrade
  else
    # Otherwise, perform update over SSH
    ssh root@"$node" "apt-get update && apt-get -y dist-upgrade"
  fi
done

echo "All servers have been successfully updated."
