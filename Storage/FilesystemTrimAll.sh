#!/bin/bash
#
# FilesystemTrimAll.sh
#
# A script to run TRIM on all relevant filesystems for LXC containers and VMs (via qm)
# that have the guest agent enabled. This can be done for the current host or all hosts
# in the Proxmox cluster.
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
#   1) ./FilesystemTrimAll.sh
#      Runs fstrim on the current host only (default behavior).
#
#   2) ./FilesystemTrimAll.sh host
#      Same as above, explicitly specifying "host".
#
#   3) ./FilesystemTrimAll.sh all
#      Attempts to run fstrim on every node in the cluster.
#
# Note:
#   - Ensure you're running this as root or via sudo.
#   - Check that "qm" and "pct" commands are installed and accessible.
#   - For cluster-wide operation, SSH keys between nodes should be set up 
#     for passwordless login (or be prepared to enter credentials).
#

# --- Preliminary Checks -----------------------------------------------------
set -e

if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root (sudo)."
  exit 1
fi

if ! command -v qm &>/dev/null; then
  echo "Error: 'qm' not found. Are you sure this is a Proxmox node?"
  exit 2
fi

if ! command -v pct &>/dev/null; then
  echo "Error: 'pct' not found. Are you sure this is a Proxmox node?"
  exit 3
fi

# --- Functions -------------------------------------------------------------

trim_on_node() {
  local NODE="$1"

  echo "---- [Node: $NODE] Gathering QEMU VMs with guest agent enabled... ----"

  # We retrieve a list of VMIDs that have 'agent: 1' or 'agent: enabled=1' in config
  # The config line can differ, so we check generically for 'agent:.*enable'
  local VM_IDS
  VM_IDS=$(ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$NODE" \
    "qm list --full | awk 'NR>1 {print \$1}'" 2>/dev/null || true)

  if [[ -z "$VM_IDS" ]]; then
    echo "[Node: $NODE] No QEMU VMs found."
  else
    for VMID in $VM_IDS; do
      if ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$NODE" \
        "qm config $VMID 2>/dev/null | grep -Eq '^agent:.*(enable=1|=1)'" ; then
        echo "[Node: $NODE] Trimming QEMU VM ID: $VMID"
        # We attempt to run fstrim -a inside the guest
        ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$NODE" \
          "qm guest exec $VMID -- fstrim -a || echo 'Warning: fstrim command failed on VM $VMID.'"
      else
        echo "[Node: $NODE] Skipping QEMU VM ID: $VMID (guest agent not enabled)."
      fi
    done
  fi

  echo "---- [Node: $NODE] Gathering LXC containers... ----"
  local CT_IDS
  CT_IDS=$(ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$NODE" \
    "pct list --full | awk 'NR>1 {print \$1}'" 2>/dev/null || true)

  if [[ -z "$CT_IDS" ]]; then
    echo "[Node: $NODE] No LXC containers found."
  else
    for CTID in $CT_IDS; do
      echo "[Node: $NODE] Trimming LXC CT ID: $CTID"
      ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$NODE" \
        "pct exec $CTID -- fstrim -a || echo 'Warning: fstrim command failed on CT $CTID.'"
    done
  fi
}

# --- Main Script Logic -----------------------------------------------------

MODE="$1"
if [[ -z "$MODE" ]]; then
  MODE="host"
fi

case "$MODE" in
  host)
    echo "Operating on current node only..."
    CURRENT_NODE=$(hostname)
    # No SSH needed for local node, so we slightly modify the function logic:
    echo "---- [Node: $CURRENT_NODE] Gathering QEMU VMs with guest agent enabled... ----"

    VM_IDS=$(qm list --full | awk 'NR>1 {print $1}')
    if [[ -z "$VM_IDS" ]]; then
      echo "[Node: $CURRENT_NODE] No QEMU VMs found."
    else
      for VMID in $VM_IDS; do
        if qm config "$VMID" 2>/dev/null | grep -Eq '^agent:.*(enable=1|=1)'; then
          echo "[Node: $CURRENT_NODE] Trimming QEMU VM ID: $VMID"
          qm guest exec "$VMID" -- fstrim -a || \
            echo "Warning: fstrim command failed on VM $VMID."
        else
          echo "[Node: $CURRENT_NODE] Skipping QEMU VM ID: $VMID (guest agent not enabled)."
        fi
      done
    fi

    echo "---- [Node: $CURRENT_NODE] Gathering LXC containers... ----"
    CT_IDS=$(pct list --full | awk 'NR>1 {print $1}')
    if [[ -z "$CT_IDS" ]]; then
      echo "[Node: $CURRENT_NODE] No LXC containers found."
    else
      for CTID in $CT_IDS; do
        echo "[Node: $CURRENT_NODE] Trimming LXC CT ID: $CTID"
        pct exec "$CTID" -- fstrim -a || \
          echo "Warning: fstrim command failed on CT $CTID."
      done
    fi
    ;;

  all)
    echo "Operating on all nodes in the cluster..."
    # Retrieve cluster nodes
    # 'pvesh get /cluster/resources --type node | jq -r .[].name' can list node names
    if ! command -v pvesh &>/dev/null; then
      echo "Error: 'pvesh' not found. Unable to list all nodes in the cluster."
      exit 4
    fi
    
    NODE_LIST=$(pvesh get /cluster/resources --type node 2>/dev/null | grep '"name"' | awk -F'"' '{print $4}')
    if [[ -z "$NODE_LIST" ]]; then
      echo "No cluster nodes found or failed to retrieve node list."
      exit 0
    fi

    for NODE in $NODE_LIST; do
      echo "========================================================================"
      echo "Proceeding with Node: $NODE"
      echo "========================================================================"
      trim_on_node "$NODE"
    done
    ;;

  *)
    echo "Usage: $0 [all|host]"
    echo "Error: Invalid argument '$MODE'"
    exit 1
    ;;
esac

echo "Done. All relevant TRIM operations have been attempted."
