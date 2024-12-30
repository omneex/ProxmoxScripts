#!/bin/bash
#
# BulkSetMemory.sh
#
# This script sets the memory (RAM) and optional swap allocation for a series of LXC containers.
#
# Usage:
#   ./BulkSetMemory.sh <start_ct_id> <num_cts> <memory_MB> [swap_MB]
#
# Example:
#   ./BulkSetMemory.sh 400 3 2048
#   Sets containers 400..402 to 2048 MB of RAM, no swap
#
#   ./BulkSetMemory.sh 400 3 2048 1024
#   Sets containers 400..402 to 2048 MB of RAM and 1024 MB of swap

if [ $# -lt 3 ]; then
  echo "Usage: $0 <start_ct_id> <num_cts> <memory_MB> [swap_MB]"
  exit 1
fi

START_CT_ID="$1"
NUM_CTS="$2"
MEMORY_MB="$3"
SWAP_MB="${4:-0}"  # default 0 if not provided

echo "=== Starting memory config update for $NUM_CTS container(s) ==="
echo " - Starting container ID: $START_CT_ID"
echo " - Memory (MB): $MEMORY_MB"
echo " - Swap (MB): $SWAP_MB"

for (( i=0; i<NUM_CTS; i++ )); do
  CURRENT_CT_ID=$((START_CT_ID + i))

  # Check if container exists
  if pct config "$CURRENT_CT_ID" &>/dev/null; then
    echo "Updating memory for container $CURRENT_CT_ID..."
    pct set "$CURRENT_CT_ID" -memory "$MEMORY_MB" -swap "$SWAP_MB"

    if [ $? -eq 0 ]; then
      echo " - Successfully updated memory for CT $CURRENT_CT_ID."
    else
      echo " - Failed to update memory for CT $CURRENT_CT_ID."
    fi
  else
    echo " - Container $CURRENT_CT_ID does not exist. Skipping."
  fi
done

echo "=== Bulk memory config change process complete! ==="
