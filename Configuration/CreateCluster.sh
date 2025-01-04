#!/usr/bin/env bash
#
# CreateCluster.sh
#
# A script to create a new Proxmox cluster on a single host, specifying:
#   1) The cluster name (e.g. "MyCluster")
#   2) The management (Corosync) IP for cluster communication
#
# Usage:
#   ./CreateCluster.sh <clustername> <mon-ip>
#
# Example:
#   ./CreateCluster.sh myCluster 192.168.100.10
#
# After running this script, you can join other Proxmox nodes to the cluster with:
#   pvecm add <mon-ip-of-this-node>
#

# --- Check for required arguments -------------------------------------------
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <clustername> <mon-ip>"
  exit 1
fi

CLUSTER_NAME="$1"
MON_IP="$2"

# --- Preliminary checks -----------------------------------------------------
# 1) Make sure this host is not already part of a cluster
if [ -f "/etc/pve/.members" ]; then
  echo "WARNING: This host appears to have a cluster config (/etc/pve/.members)."
  echo "If it's already part of a cluster, creating a new one will cause conflicts."
  echo "Press Ctrl-C to abort, or wait 5s to continue..."
  sleep 5
fi

# 2) Validate that 'pvecm' command exists
if ! command -v pvecm >/dev/null 2>&1; then
  echo "Error: 'pvecm' command not found. Are you sure this is a Proxmox host?"
  exit 2
fi

# --- Create the cluster -----------------------------------------------------
echo "Creating new Proxmox cluster: $CLUSTER_NAME"
echo "Using bindnet0_addr: $MON_IP"

pvecm create "$CLUSTER_NAME" --bindnet0_addr "$MON_IP"

# --- Post-create notice -----------------------------------------------------
echo
echo "Cluster '$CLUSTER_NAME' created on IP $MON_IP."
echo "To verify status:  pvecm status"
echo "To join another node to this cluster: on the other node run:"
echo "  pvecm add $MON_IP"
