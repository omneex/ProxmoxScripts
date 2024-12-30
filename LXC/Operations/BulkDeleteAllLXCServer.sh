#!/bin/bash
#
# BulkDeleteAllLXCOnServer.sh
#
# This script deletes all LXC containers on the local Proxmox node.
# It enumerates container IDs with 'pct list', then stops and destroys each.
#
# Usage:
#   ./BulkDeleteAllLXCOnServer.sh
#
# Warning:
#   This will remove ALL LXC containers on this node. Use with caution!

echo "=== Listing all containers on this node ==="
CONTAINER_IDS=$(pct list | awk 'NR>1 {print $1}')

if [ -z "$CONTAINER_IDS" ]; then
  echo "No LXC containers found on this node."
  exit 0
fi

echo "The following containers will be deleted:"
echo "$CONTAINER_IDS"
read -p "Are you sure you want to delete ALL of these containers? (yes/no) " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Aborting."
  exit 1
fi

for CT_ID in $CONTAINER_IDS; do
  echo "Stopping CT $CT_ID ..."
  pct stop "$CT_ID" &>/dev/null

  echo "Destroying CT $CT_ID ..."
  pct destroy "$CT_ID" &>/dev/null

  if [ $? -eq 0 ]; then
    echo " - Successfully deleted CT $CT_ID"
  else
    echo " - Failed to delete CT $CT_ID"
  fi
done

echo "=== All LXC containers on this node have been deleted. ==="
