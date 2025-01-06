#!/bin/bash
#
# AddNode.sh
#
# A script to join a new Proxmox node to an existing cluster, with optional multi-ring support.
# Run **on the NEW node** that you want to add to the cluster.
#
# Usage:
#   ./AddNode.sh <cluster-IP> [<ring0-addr>] [<ring1-addr>]
#
# Examples:
#   1) Single-ring (just specify cluster IP):
#      ./AddNode.sh 192.168.100.10
#
#   2) Two-ring (ring0 + ring1):
#      ./AddNode.sh 192.168.100.10 192.168.200.20 192.168.201.20
#
#   3) If you only want to set ring0_addr but not ring1_addr (still single ring):
#      ./AddNode.sh 192.168.100.10 192.168.200.20
#
# After running this script, you will be prompted for the 'root@pam' password
# of the existing cluster node. Then pvecm will transfer the necessary keys
# and config to this node, completing the cluster join.

set -e

# --- Ensure we are root -----------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root (sudo)."
  exit 1
fi

# --- Parse Arguments --------------------------------------------------------
CLUSTER_IP="$1"
RING0_ADDR="$2"   # optional
RING1_ADDR="$3"   # optional

if [[ -z "$CLUSTER_IP" ]]; then
  echo "Usage: $0 <existing-cluster-IP> [<ring0-addr>] [<ring1-addr>]"
  exit 1
fi

# --- Preliminary Checks -----------------------------------------------------
# 1) Check if node is already in a cluster
if [ -f "/etc/pve/.members" ]; then
  echo "Detected /etc/pve/.members. This node may already be in a cluster."
  echo "Press Ctrl-C to abort, or wait 5 seconds to continue..."
  sleep 5
fi

# 2) Verify pvecm is available
if ! command -v pvecm >/dev/null 2>&1; then
  echo "Error: 'pvecm' not found. Are you sure this is a Proxmox node?"
  exit 2
fi

# --- Join the Cluster -------------------------------------------------------
CMD="pvecm add $CLUSTER_IP"

if [[ -n "$RING0_ADDR" ]]; then
  CMD+=" --ring0_addr $RING0_ADDR"
fi

if [[ -n "$RING1_ADDR" ]]; then
  CMD+=" --ring1_addr $RING1_ADDR"
fi

echo "=== Join Proxmox Cluster ==="
echo "Existing cluster IP: $CLUSTER_IP"
if [[ -n "$RING0_ADDR" ]]; then
  echo "Using ring0_addr: $RING0_ADDR"
fi
if [[ -n "$RING1_ADDR" ]]; then
  echo "Using ring1_addr: $RING1_ADDR"
fi

echo
echo "Running command:"
echo "  $CMD"
echo
echo "You will be asked for the 'root@pam' password on the EXISTING cluster node."
echo

# Execute the join
$CMD

echo
echo "=== Done ==="
echo "Check cluster status with:  pvecm status"
echo "You should see this node listed as part of the cluster."
