#!/bin/bash
#
# BulkStartLXC.sh
#
# This script starts multiple LXC containers whose IDs are provided as arguments.
#
# Usage:
#   ./BulkStartLXC.sh <CT_ID_1> <CT_ID_2> ...
#
# Example:
#   ./BulkStartLXC.sh 200 201 202
#   This will start containers 200, 201, and 202
#

if [ $# -lt 1 ]; then
  echo "Usage: $0 <CT_ID_1> [<CT_ID_2> ...]"
  exit 1
fi

echo "=== Starting specified LXC containers ==="
for CT_ID in "$@"; do
  if pct config "$CT_ID" &>/dev/null; then
    echo "Starting CT $CT_ID ..."
    pct start "$CT_ID"
    if [ $? -eq 0 ]; then
      echo " - CT $CT_ID started."
    else
      echo " - Failed to start CT $CT_ID."
    fi
  else
    echo " - CT $CT_ID does not exist, skipping."
  fi
done

echo "=== Bulk start process complete. ==="
