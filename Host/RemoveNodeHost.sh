#!/bin/bash
#
# RemoveNodeHost.sh
#
# This script removes *this* Proxmox node from a cluster, assuming the cluster
# no longer trusts or recognizes this node. It cleans up local Corosync/PMXCFS
# files so the node reverts to standalone mode.
#
# Usage:
#   sudo ./RemoveNodeHost.sh
#
# Steps:
#   1) Stop cluster services (corosync, pve-cluster).
#   2) Remove local Corosync configs (/etc/pve/corosync.conf, /etc/corosync/).
#   3) Remove /etc/pve/nodes/<this_node_name> local references.
#   4) Start pve-cluster again (standalone).
#
# Afterwards, you can re-add this node to a new or existing cluster with:
#   pvecm add <IP-of-other-cluster-node>
#
# CAUTION: This is destructive—your node will no longer be part of any cluster.

set -e  # Exit on error

# --- Must be root -----------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root (sudo)."
  exit 1
fi

# --- Check for pve-cluster/pvecm commands -----------------------------------
if ! command -v pvecm >/dev/null 2>&1; then
  echo "Error: 'pvecm' not found. Are you sure this is a Proxmox node?"
  exit 2
fi
if ! systemctl list-units --type=service | grep -q pve-cluster; then
  echo "Warning: 'pve-cluster' service not found or not active. Proceeding anyway..."
fi

# --- Get local node name (Proxmox "nodename") --------------------------------
NODE_NAME="$(pvecm nodename 2>/dev/null || hostname --short)"
if [[ -z "$NODE_NAME" ]]; then
  echo "Could not determine local node name. Exiting."
  exit 3
fi

echo "=== Self Removal from Proxmox Cluster ==="
echo "Node name detected: $NODE_NAME"
echo
echo "This will remove local cluster configs and revert this node to a standalone setup."
echo "It assumes the cluster already 'untrusted' or removed this node externally."
echo "Are you sure you want to proceed? (y/N)"
read -r CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

echo "Stopping cluster services..."
systemctl stop corosync || true
systemctl stop pve-cluster || true

echo "Removing Corosync config files..."
rm -f /etc/pve/corosync.conf 2>/dev/null || true
rm -rf /etc/corosync/* 2>/dev/null || true

if [ -d "/etc/pve/nodes/$NODE_NAME" ]; then
  echo "Removing /etc/pve/nodes/$NODE_NAME ..."
  rm -rf "/etc/pve/nodes/$NODE_NAME"
fi

echo "Restarting pve-cluster in standalone mode..."
systemctl start pve-cluster || true

echo "Stopping corosync..."
systemctl stop corosync || true  # ensure it's not running

echo
echo "=== Done ==="
echo "Node '$NODE_NAME' is no longer in any cluster and runs standalone."
echo "You can verify by running:  pvecm status"
echo
echo "If you wish to join an existing cluster, run on this node:"
echo "  pvecm add <IP-of-other-cluster-node>"
