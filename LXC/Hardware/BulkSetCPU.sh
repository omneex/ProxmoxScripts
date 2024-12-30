#!/bin/bash
#
# BulkSetCPU.sh
#
# This script sets the CPU type and core count for a series of LXC containers.
#
# Usage:
#   ./BulkSetCPU.sh <start_ct_id> <num_cts> <cpu_type> <core_count> [sockets]
#
# Example:
#   ./BulkSetCPU.sh 400 3 host 4
#   This sets containers 400..402 to CPU type=host and 4 cores
#
#   ./BulkSetCPU.sh 400 3 host 4 2
#   Sets containers 400..402 to CPU type=host, 4 cores, 2 sockets

if [ $# -lt 4 ]; then
  echo "Usage: $0 <start_ct_id> <num_cts> <cpu_type> <core_count> [sockets]"
  exit 1
fi

START_CT_ID="$1"
NUM_CTS="$2"
CPU_TYPE="$3"
CORE_COUNT="$4"
SOCKETS="${5:-1}"  # default 1 socket if not provided

echo "=== Starting CPU config update for $NUM_CTS container(s) ==="
echo " - Starting container ID: $START_CT_ID"
echo " - CPU Type: $CPU_TYPE"
echo " - Core Count: $CORE_COUNT"
echo " - Sockets: $SOCKETS"

for (( i=0; i<NUM_CTS; i++ )); do
  CURRENT_CT_ID=$((START_CT_ID + i))

  # Check if container exists
  if pct config "$CURRENT_CT_ID" &>/dev/null; then
    echo "Updating CPU for container $CURRENT_CT_ID..."
    pct set "$CURRENT_CT_ID" -cpu "$CPU_TYPE" -cores "$CORE_COUNT" -sockets "$SOCKETS"

    if [ $? -eq 0 ]; then
      echo " - Successfully updated CPU settings for CT $CURRENT_CT_ID."
    else
      echo " - Failed to update CPU settings for CT $CURRENT_CT_ID."
    fi
  else
    echo " - Container $CURRENT_CT_ID does not exist. Skipping."
  fi
done

echo "=== Bulk CPU config change process complete! ==="
