#!/bin/bash
#
# BulkChangeNetwork.sh
#
# This script changes the network interface for a series of LXC containers.
# Typically, this means changing the bridge (e.g., vmbr0 -> vmbr1) and/or the interface name (eth0 -> eth1).
#
# Usage:
#   ./BulkChangeNetwork.sh <start_ct_id> <num_cts> <bridge> [interface_name]
#
# Example:
#   ./BulkChangeNetwork.sh 400 3 vmbr1 eth1
#   This changes containers 400..402 to use net0 => name=eth1,bridge=vmbr1
#
#   ./BulkChangeNetwork.sh 400 3 vmbr1
#   This changes containers 400..402 to use net0 => name=eth0,bridge=vmbr1 (default eth0)

if [ $# -lt 3 ]; then
  echo "Usage: $0 <start_ct_id> <num_cts> <bridge> [interface_name]"
  exit 1
fi

START_CT_ID="$1"
NUM_CTS="$2"
BRIDGE="$3"
IF_NAME="${4:-eth0}"  # Default to eth0 if not provided

echo "=== Starting network interface update for $NUM_CTS container(s) ==="
echo " - Starting container ID: $START_CT_ID"
echo " - New bridge: $BRIDGE"
echo " - Interface name: $IF_NAME"

for (( i=0; i<NUM_CTS; i++ )); do
  CURRENT_CT_ID=$((START_CT_ID + i))

  # Check if container exists
  if pct config "$CURRENT_CT_ID" &>/dev/null; then
    echo "Updating network interface for container $CURRENT_CT_ID..."

    # Apply the new bridge + name on net0
    pct set "$CURRENT_CT_ID" -net0 name="$IF_NAME",bridge="$BRIDGE"

    if [ $? -eq 0 ]; then
      echo " - Successfully updated network interface for CT $CURRENT_CT_ID."
    else
      echo " - Failed to update network interface for CT $CURRENT_CT_ID."
    fi
  else
    echo " - Container $CURRENT_CT_ID does not exist. Skipping."
  fi
done

echo "=== Bulk interface change process complete! ==="
