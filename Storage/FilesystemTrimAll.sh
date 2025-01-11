#!/bin/bash
#
# FilesystemTrimAll.sh
#
# A script to run TRIM on all relevant filesystems for LXC containers and QEMU VMs 
# (via qm) that have the guest agent enabled. This can be done for the current host 
# or all hosts in the Proxmox cluster.
#
# Usage:
#   ./FilesystemTrimAll.sh [all|host]
#
# Description:
#   - If "host" is specified (or no argument is given), the script will run fstrim 
#     on this Proxmox node only.
#   - If "all" is specified, the script will attempt to run fstrim on all nodes in 
#     the cluster, via SSH.
#   - For QEMU VMs, only those which have the guest agent enabled will be trimmed.
#   - LXC containers do not require the guest agent; if they have fstrim available, 
#     they will be trimmed.
#
# Examples:
#   # Runs fstrim on the current host only (default behavior).
#   ./FilesystemTrimAll.sh
#
#   # Same as above, explicitly specifying "host".
#   ./FilesystemTrimAll.sh host
#
#   # Attempts to run fstrim on every node in the cluster.
#   ./FilesystemTrimAll.sh all
#
# Note:
#   - Ensure you’re running this as root or via sudo.
#   - This script can only run on a Proxmox node.
#   - For cluster-wide operation, SSH keys between nodes should be set up for 
#     passwordless login (or be prepared to enter credentials).
#

source "$UTILITIES"

###############################################################################
# Preliminary Checks
###############################################################################
check_root
check_proxmox

###############################################################################
# Function Definitions
###############################################################################
trim_on_node() {
  local node="$1"

  echo "---- [Node: \"$node\"] Gathering QEMU VMs with guest agent enabled... ----"
  local vmIds
  vmIds=$(ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$node" \
    "qm list --full | awk 'NR>1 {print \$1}'" 2>/dev/null || true)

  if [[ -z "$vmIds" ]]; then
    echo "[Node: \"$node\"] No QEMU VMs found."
  else
    for vmId in $vmIds; do
      if ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$node" \
        "qm config \"$vmId\" 2>/dev/null | grep -Eq '^agent:.*(enable=1|=1)'" ; then
        echo "[Node: \"$node\"] Trimming QEMU VM ID: \"$vmId\""
        ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$node" \
          "qm guest exec \"$vmId\" -- fstrim -a || echo 'Warning: fstrim command failed on VM \"$vmId\".'"
      else
        echo "[Node: \"$node\"] Skipping QEMU VM ID: \"$vmId\" (guest agent not enabled)."
      fi
    done
  fi

  echo "---- [Node: \"$node\"] Gathering LXC containers... ----"
  local ctIds
  ctIds=$(ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$node" \
    "pct list --full | awk 'NR>1 {print \$1}'" 2>/dev/null || true)

  if [[ -z "$ctIds" ]]; then
    echo "[Node: \"$node\"] No LXC containers found."
  else
    for ctId in $ctIds; do
      echo "[Node: \"$node\"] Trimming LXC CT ID: \"$ctId\""
      ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$node" \
        "pct exec \"$ctId\" -- fstrim -a || echo 'Warning: fstrim command failed on CT \"$ctId\".'"
    done
  fi
}

###############################################################################
# Main Script Logic
###############################################################################
mode="$1"
if [[ -z "$mode" ]]; then
  mode="host"
fi

case "$mode" in
  host)
    echo "Operating on current node only..."
    localNode="$(hostname)"

    echo "---- [Node: \"$localNode\"] Gathering QEMU VMs with guest agent enabled... ----"
    local vmIds
    vmIds=$(qm list --full | awk 'NR>1 {print $1}')
    if [[ -z "$vmIds" ]]; then
      echo "[Node: \"$localNode\"] No QEMU VMs found."
    else
      for vmId in $vmIds; do
        if qm config "$vmId" 2>/dev/null | grep -Eq '^agent:.*(enable=1|=1)'; then
          echo "[Node: \"$localNode\"] Trimming QEMU VM ID: \"$vmId\""
          qm guest exec "$vmId" -- fstrim -a || \
            echo "Warning: fstrim command failed on VM \"$vmId\"."
        else
          echo "[Node: \"$localNode\"] Skipping QEMU VM ID: \"$vmId\" (guest agent not enabled)."
        fi
      done
    fi

    echo "---- [Node: \"$localNode\"] Gathering LXC containers... ----"
    local ctIds
    ctIds=$(pct list --full | awk 'NR>1 {print $1}')
    if [[ -z "$ctIds" ]]; then
      echo "[Node: \"$localNode\"] No LXC containers found."
    else
      for ctId in $ctIds; do
        echo "[Node: \"$localNode\"] Trimming LXC CT ID: \"$ctId\""
        pct exec "$ctId" -- fstrim -a || \
          echo "Warning: fstrim command failed on CT \"$ctId\"."
      done
    fi
    ;;

  all)
    echo "Operating on all nodes in the cluster..."
    local nodeList
    nodeList=$(pvesh get /cluster/resources --type node 2>/dev/null | grep '"name"' | awk -F'"' '{print $4}')

    if [[ -z "$nodeList" ]]; then
      echo "No cluster nodes found or failed to retrieve node list."
      exit 0
    fi

    for node in $nodeList; do
      echo "========================================================================"
      echo "Proceeding with Node: \"$node\""
      echo "========================================================================"
      trim_on_node "$node"
    done
    ;;

  *)
    echo "Usage: \"$0\" [all|host]"
    echo "Error: Invalid argument \"$mode\""
    exit 1
    ;;
esac

echo "Done. All relevant TRIM operations have been attempted."
