#!/bin/bash
#
# DeleteCluster.sh
#
# Script to remove a single-node Proxmox cluster configuration,
# returning the node to a standalone setup.
#
# Usage:
#   ./DeleteCluster.sh
#
# Warning:
#   - If this node is part of a multi-node cluster, first remove other nodes
#     from the cluster (pvecm delnode <nodename>) until this is the last node.
#   - This process is DESTRUCTIVE and will remove cluster configuration.
#

source "$UTILITIES"

###############################################################################
# Preliminary Checks
###############################################################################
check_root        # Ensure script is run as root
check_proxmox     # Ensure this is a Proxmox node

###############################################################################
# Main Script Logic
###############################################################################
echo "=== Proxmox Cluster Removal (Single-Node) ==="
echo "This will remove Corosync/cluster configuration from this node."
read -r -p "Proceed? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Aborted."
  exit 1
fi

nodeCount="$(get_number_of_cluster_nodes)"
if [[ "$nodeCount" -gt 1 ]]; then
  echo "Error: This script is for a single-node cluster only."
  echo "Current cluster shows \"$nodeCount\" nodes. Remove other nodes first, then re-run."
  exit 2
fi

echo "Stopping cluster services..."
systemctl stop corosync || true
systemctl stop pve-cluster || true

echo "Removing Corosync config from /etc/pve and /etc/corosync..."
rm -f "/etc/pve/corosync.conf" 2>/dev/null || true
rm -rf "/etc/corosync/"* 2>/dev/null || true

# Optionally remove additional cluster-related config (use caution):
# rm -f /etc/pve/cluster.conf 2>/dev/null || true

echo "Restarting pve-cluster (it will now run standalone)..."
systemctl start pve-cluster

echo "Verifying that corosync is not running..."
systemctl stop corosync 2>/dev/null || true
systemctl disable corosync 2>/dev/null || true

echo "=== Done ==="
echo "This node is no longer part of any Proxmox cluster."
echo "You can verify by running 'pvecm status' (it should show no cluster)."
