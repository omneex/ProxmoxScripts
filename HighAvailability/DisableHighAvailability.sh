#!/bin/bash
#
# DisableHAOnNode.sh
#
# This script disables High Availability (HA) on a single Proxmox node by:
#   1. Disabling or removing any HA resources tied to this node.
#   2. Stopping and disabling the HA services (pve-ha-crm, pve-ha-lrm) on the node.
#
# Usage:
#   ./DisableHAOnNode.sh <node_name>
#
# Example:
#   ./DisableHAOnNode.sh pve-node2
#
# Notes:
#   - If you're using a multi-node cluster, ensure that no critical HA resources rely on this node.
#   - A single-node "cluster" does not benefit from HA, so this script effectively cleans up HA configs.

###############################################################################
# MAIN
###############################################################################

# 1. Check usage
if [ -z "$1" ]; then
  echo "Usage: $0 <node_name>"
  echo "Example: $0 pve-node2"
  exit 1
fi

TARGET_NODE="$1"

echo "=== Disabling HA on node: $TARGET_NODE ==="

# 2. Identify HA resources referencing this node
#    We list all HA resources, then filter any that have a 'node' or 'preferred node' matching $TARGET_NODE.
#    pvesh get /cluster/ha/resources returns a JSON array. We'll parse it with 'jq'.
echo "=== Checking for HA resources on node '$TARGET_NODE'... ==="
HA_RESOURCES=$(pvesh get /cluster/ha/resources --output-format json | jq -r '.[] | select(.statePath | contains("'"$TARGET_NODE"'")) | .sid')

if [ -z "$HA_RESOURCES" ]; then
  echo " - No HA resources found referencing node '$TARGET_NODE'."
else
  echo " - Found HA resources referencing node '$TARGET_NODE':"
  echo "$HA_RESOURCES"  
  echo
  # 2a. Disable or remove these HA resources
  #     Option A: disable them (set group to '' or remove them from scheduling).
  #     Option B: remove them from HA entirely.
  #     Below we choose to remove them from HA. Adjust to your preference.
  for RES in $HA_RESOURCES; do
    echo "Removing HA resource $RES ..."
    pvesh delete /cluster/ha/resources/"$RES"
    if [ $? -eq 0 ]; then
      echo " - Successfully removed HA resource: $RES"
    else
      echo " - Failed to remove HA resource: $RES"
    fi
  done
fi

echo

# 3. Stop and disable HA services on the target node
#    - pve-ha-crm: The cluster resource manager
#    - pve-ha-lrm: The local resource manager
echo "=== Stopping and disabling HA services on node '$TARGET_NODE' ==="

# 3a. Stop services
echo "Stopping pve-ha-crm and pve-ha-lrm on $TARGET_NODE..."
ssh root@"$TARGET_NODE" "systemctl stop pve-ha-crm pve-ha-lrm"

# 3b. Disable services on system startup
echo "Disabling pve-ha-crm and pve-ha-lrm on $TARGET_NODE..."
ssh root@"$TARGET_NODE" "systemctl disable pve-ha-crm pve-ha-lrm"

echo
echo "=== HA has been disabled on node: $TARGET_NODE ==="
echo "Please verify via 'systemctl status pve-ha-crm pve-ha-lrm' on the node."
