#!/bin/bash
#
# BulkStopLXCs.sh
#
# This script stops multiple LXC containers whose IDs are provided as arguments.
#
# Usage:
#   ./BulkStopLXCs.sh <CT_ID_1> <CT_ID_2> ...
#
# Example:
#   ./BulkStopLXCs.sh 200 201 202
#   This will stop containers 200, 201, and 202
#

if [ $# -lt 1 ]; then
  echo "Usage: $0 <CT_ID_1> [<CT_ID_2> ...]"
  exit 1
fi

echo "=== Stopping specified LXC containers ==="
for CT_ID in "$@"; do
  if pct config "$CT_ID" &>/dev/null; then
    echo "Stopping CT $CT_ID ..."
    pct stop "$CT_ID"
    if [ $? -eq 0 ]; then
      echo " - CT $CT_ID stopped."
    else
      echo " - Failed to stop CT $CT_ID."
    fi
  else
    echo " - CT $CT_ID does not exist, skipping."
  fi
done

echo "=== Bulk stop process complete. ==="
