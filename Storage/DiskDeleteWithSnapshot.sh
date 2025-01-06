#!/bin/bash
#
# This script is designed to manage snapshots and disk images within a Ceph storage pool.
# Specifically, it checks for a particular snapshot named "__base__" and, if it is the only snapshot, 
# unprotects and deletes it before removing the associated disk. This script is ideal for cleaning up after 
# operations that require a rollback to a snapshot state or for freeing up storage space by removing unused 
# or unnecessary snapshots and disks.
#
# Usage:
# ./DiskDeleteWSnapshot.sh <pool_name> <disk_name>
#   pool_name - The name of the Ceph pool where the disk is located. 


# Assigning input arguments
POOL_NAME="$1"
DISK_NAME="$2"

# Function to check and delete the snapshot
function delete_snapshot() {
    local pool=$1
    local disk=$2

    echo "Listing snapshots for ${pool}/${disk}..."

    # Get the snapshot list
    snapshot_list=$(rbd snap ls "${pool}/${disk}")
    if [ $? -ne 0 ]; then
        echo "Failed to list snapshots for ${pool}/${disk}"
        return 1
    fi

    echo "Snapshot list:"
    echo "$snapshot_list"

    # Check if __base__ is the only snapshot
    if echo "$snapshot_list" | grep -q "__base__" && [ $(echo "$snapshot_list" | grep -v "NAME" | wc -l) -eq 1 ]; then
        echo "Only __base__ snapshot found. Proceeding with deletion..."

        # Unprotect the snapshot
        rbd snap unprotect "${pool}/${disk}@__base__"
        if [ $? -ne 0 ]; then
            echo "Failed to unprotect the snapshot ${pool}/${disk}@__base__"
            return 1
        fi

        # Delete the snapshot
        rbd snap rm "${pool}/${disk}@__base__"
        if [ $? -ne 0 ]; then
            echo "Failed to remove the snapshot ${pool}/${disk}@__base__"
            return 1
        fi

        # Remove the disk
        rbd rm "${disk}" -p "${pool}"
        if [ $? -ne 0 ]; then
            echo "Failed to remove the disk ${disk} in pool ${pool}"
            return 1
        fi

        echo "__base__ snapshot and disk ${disk} have been deleted."
    else
        echo "Other snapshots exist or __base__ is not the only snapshot. No action taken."
    fi
}

# Validate inputs
if [ -z "$POOL_NAME" ] || [ -z "$DISK_NAME" ]; then
    echo "Usage: $0 <pool_name> <disk_name>"
    exit 1
fi

# Calling the function with the provided pool and disk name
delete_snapshot "$POOL_NAME" "$DISK_NAME"
