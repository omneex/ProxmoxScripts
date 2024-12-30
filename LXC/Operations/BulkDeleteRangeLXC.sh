#!/bin/bash
#
# BulkDeleteRangeLXC.sh
#
# This script deletes a range of LXC containers by ID, stopping them first if needed,
# then destroying them.
#
# Usage:
#   ./BulkDeleteRangeLXCs.sh <START_ID> <END_ID>
# 
# Example:
#   ./BulkDeleteRangeLXCs.sh 200 204
#   This will delete CTs 200, 201, 202, 203, 204
#

if [ $# -ne 2 ]; then
  echo "Usage: $0 <START_ID> <END_ID>"
  exit 1
fi

START_ID="$1"
END_ID="$2"

# Ensure START_ID <= END_ID
if [ "$START_ID" -gt "$END_ID" ]; then
  echo "Error: START_ID ($START_ID) is greater than END_ID ($END_ID)."
  exit 1
fi

echo "=== Deleting containers from ID $START_ID to $END_ID ==="
for (( CT_ID=START_ID; CT_ID<=END_ID; CT_ID++ )); do
  if pct config "$CT_ID" &>/dev/null; then
    echo "Stopping CT $CT_ID ..."
    pct stop "$CT_ID" &>/dev/null

    echo "Destroying CT $CT_ID ..."
    pct destroy "$CT_ID" &>/dev/null

    if [ $? -eq 0 ]; then
      echo " - Successfully deleted CT $CT_ID"
    else
      echo " - Failed to delete CT $CT_ID"
    fi
  else
    echo " - CT $CT_ID does not exist, skipping."
  fi
done

echo "=== Bulk deletion complete. ==="
