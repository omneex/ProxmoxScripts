#!/bin/bash
#
# BulkDeleteAllLocal.sh
#
# This script deletes all LXC containers on the local Proxmox node.
# It enumerates container IDs and stops/destroys each one.
#
# Usage:
#   ./BulkDeleteAllLocal.sh
#
# Warning:
#   This will remove ALL LXC containers on this node. Use with caution!
#

source "$UTILITIES"

###############################################################################
# Environment Checks
###############################################################################
check_root
check_proxmox

###############################################################################
# Main Logic
###############################################################################
echo "=== Listing all containers on this node ==="
readarray -t CONTAINER_IDS < <( get_server_lxc "local" )

if [ -z "${CONTAINER_IDS[*]}" ]; then
  echo "No LXC containers found on this node."
  exit 0
fi

echo "The following containers will be deleted:"
printf '%s\n' "${CONTAINER_IDS[@]}"
read -p "Are you sure you want to delete ALL of these containers? (yes/no) " confirm
if [ "$confirm" != "yes" ]; then
  echo "Aborting."
  exit 1
fi

for ctId in "${CONTAINER_IDS[@]}"; do
  echo "Stopping CT \"$ctId\" ..."
  pct stop "$ctId" &>/dev/null

  echo "Destroying CT \"$ctId\" ..."
  pct destroy "$ctId" &>/dev/null

  if [ $? -eq 0 ]; then
    echo " - Successfully deleted CT \"$ctId\""
  else
    echo " - Failed to delete CT \"$ctId\""
  fi
done

echo "=== All LXC containers on this node have been deleted. ==="
