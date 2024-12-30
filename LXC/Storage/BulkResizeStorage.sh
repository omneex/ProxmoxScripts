#!/bin/bash
#
# BulkResizeStorageLXC.sh
#
# This script resizes a specified disk (typically rootfs) of each LXC container in a range
# to a given new size (e.g., 20G).
#
# Usage:
#   ./BulkResizeStorageLXC.sh <start_id> <end_id> <disk_id> <new_size>
#
# Arguments:
#   start_id  - The starting LXC ID.
#   end_id    - The ending LXC ID.
#   disk_id   - The disk identifier (e.g., rootfs or mp0).
#   new_size  - The new size or size increment (e.g. '20G' or '+5G').
#
# Example:
#   ./BulkResizeStorageLXC.sh 100 105 rootfs 20G
#   Resizes the rootfs of LXCs 100..105 to 20G each.
#
#   ./BulkResizeStorageLXC.sh 100 105 rootfs +5G
#   Increases the rootfs size of LXCs 100..105 by 5G.

if [ $# -lt 4 ]; then
    echo "Usage: $0 <start_id> <end_id> <disk_id> <new_size>"
    exit 1
fi

START_ID="$1"
END_ID="$2"
DISK_ID="$3"
NEW_SIZE="$4"

echo "=== Bulk Resize for LXC Containers ==="
echo "Range: $START_ID to $END_ID"
echo "Disk: $DISK_ID"
echo "New size: $NEW_SIZE"
echo

for CT_ID in $(seq "$START_ID" "$END_ID"); do
    # Check if container exists
    if pct config "$CT_ID" &>/dev/null; then
        echo "Resizing $DISK_ID of LXC $CT_ID to $NEW_SIZE..."

        # Attempt resize
        pct resize "$CT_ID" "$DISK_ID" "$NEW_SIZE"
        if [ $? -eq 0 ]; then
            echo " - Successfully resized $DISK_ID of CT $CT_ID."
        else
            echo " - Failed to resize disk for CT $CT_ID."
        fi
        echo
    else
        echo "LXC $CT_ID does not exist. Skipping."
    fi
done

echo "=== Bulk resize complete! ==="
