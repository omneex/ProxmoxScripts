#!/bin/bash
#
# BulkMoveDiskLXC.sh
#
# This script moves the rootfs disk of each LXC container in a specified range
# to a new storage using 'pct move-disk'.
#
# Usage:
#   ./BulkMoveDiskLXC.sh <start_id> <end_id> <source_disk> <target_storage>
#
# Arguments:
#   start_id       - The starting LXC ID.
#   end_id         - The ending LXC ID.
#   source_disk    - The disk identifier you want to move (e.g. 'rootfs', 'mp0').
#   target_storage - The storage identifier to move the disk onto (e.g. 'local-zfs').
#
# Example:
#   ./BulkMoveDiskLXC.sh 100 105 rootfs local-zfs
#   This will move the 'rootfs' volume of LXCs 100..105 to 'local-zfs'.

if [ $# -lt 4 ]; then
    echo "Usage: $0 <start_id> <end_id> <source_disk> <target_storage>"
    exit 1
fi

START_ID="$1"
END_ID="$2"
DISK_ID="$3"
TARGET_STORAGE="$4"

echo "=== Bulk Move Disk for LXC Containers ==="
echo "Range: $START_ID to $END_ID"
echo "Disk to move: $DISK_ID"
echo "Target storage: $TARGET_STORAGE"
echo

for CT_ID in $(seq "$START_ID" "$END_ID"); do
    # Check if container exists
    if pct config "$CT_ID" &>/dev/null; then
        echo "Processing LXC $CT_ID..."

        # Check if container is running
        RUNNING=$(pct status "$CT_ID" | awk '{print $2}')
        if [ "$RUNNING" == "running" ]; then
            echo " - Container $CT_ID is running. Stopping container..."
            pct stop "$CT_ID"
            # Optional: wait a few seconds or check if it's fully stopped
        fi

        # Move the disk
        echo " - Moving $DISK_ID of CT $CT_ID to $TARGET_STORAGE ..."
        pct move-disk "$CT_ID" "$DISK_ID" "$TARGET_STORAGE"
        if [ $? -eq 0 ]; then
            echo " - Successfully moved $DISK_ID of CT $CT_ID to $TARGET_STORAGE."
        else
            echo " - Failed to move disk for CT $CT_ID."
        fi

        # (Optional) Start the container again
        # pct start "$CT_ID"
        echo
    else
        echo "LXC $CT_ID does not exist. Skipping."
    fi
done

echo "=== Bulk disk move complete! ==="
