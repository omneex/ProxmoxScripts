#!/bin/bash

# This script automates the process of deleting specific disk images from a Ceph storage pool.
# It is designed to operate over a range of virtual machine (VM) disk images, identifying each 
# by a unique naming convention and deleting them from the specified Ceph pool. This is particularly 
# useful for bulk cleaning up VM disk images in environments like virtualized data centers or cloud platforms.
#
# Usage:
# ./DiskDeleteBulk.sh <pool_name> <start_vm_index> <end_vm_index> <disk_number>
#   pool_name - The name of the Ceph pool where the disks reside.
#   start_vm_index - The starting index of the VMs whose disks are to be deleted.
#   end_vm_index - The ending index of the VMs whose disks are to be deleted.
#   disk_number - The disk identifier that is consistent across the specified VM range.
# Example:
#   ./DiskDeleteBulk.sh vm_pool 1 100 1

# Assigning input arguments
POOL_NAME="$1"
START_VM_INDEX="$2"
END_VM_INDEX="$3"
DISK_NUMBER="$4"

# Function to delete the disk
function delete_disk() {
    local pool=$1
    local disk=$2

    # Remove the disk
    rbd rm "${disk}" -p "${pool}"
    if [ $? -ne 0 ]; then
        echo "Failed to remove the disk ${disk} in pool ${pool}"
        return 1
    fi

    echo "Disk ${disk} has been deleted."
}

# Validate inputs
if [ -z "$POOL_NAME" ] || [ -z "$START_VM_INDEX" ] || [ -z "$END_VM_INDEX" ] || [ -z "$DISK_NUMBER" ]; then
    echo "Usage: $0 <pool_name> <start_vm_index> <end_vm_index> <disk_number>"
    exit 1
fi

# Loop over the range from start VM index to end VM index
for vm_index in $(seq "$START_VM_INDEX" "$END_VM_INDEX"); do
    # Construct disk name with the format vm-<vm_index>-disk-<disk_number>
    DISK_NAME="vm-${vm_index}-disk-${DISK_NUMBER}"
    
    # Calling the function with the provided pool and disk name
    delete_disk "$POOL_NAME" "$DISK_NAME"
done
