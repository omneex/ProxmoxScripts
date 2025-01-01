#!/bin/bash
#
# This script updates a stale file mount across a Proxmox VE cluster by:
#   1) Disabling the data center storage mount.
#   2) Force-unmounting the stale mount from each node.
#   3) Removing the stale directories.
#   4) Re-enabling the data center storage mount.
#
# Usage:
#   ./UpdateStaleMount.sh <storage_name> <mount_path>
#
# Arguments:
#   storage_name - The name/ID of the Proxmox storage to be disabled and then re-enabled.
#   mount_path   - The path to the stale mount point on each node (e.g., /mnt/pve/ISO).
#
# Example:
#   ./UpdateStaleMount.sh ISO_Storage /mnt/pve/ISO
#
# Notes:
#   - Ensure you have SSH access to each node from the current node (preferably key-based).
#   - Carefully review each step before running in production.

# Check if the minimum required parameters are provided
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <storage_name> <mount_path>"
    exit 1
fi

# Assigning input arguments
STORAGE_NAME=$1
MOUNT_PATH=$2

# Step 1: Disable the data center storage
echo "Disabling Proxmox storage '$STORAGE_NAME'..."
pvesm set "$STORAGE_NAME" --disable 1
if [ $? -ne 0 ]; then
    echo "Error: Failed to disable storage '$STORAGE_NAME'. Please check the storage name and permissions."
    exit 1
fi

# Step 2: Gather the list of nodes in the cluster
echo "Retrieving cluster node list..."
NODES=$(pvecm nodes | tail -n +2 | awk '{print $2}')
if [ -z "$NODES" ]; then
    echo "Error: Unable to retrieve node list. Please ensure this script is run on a Proxmox VE node with cluster membership."
    exit 1
fi

echo "Found the following nodes in the cluster:"
echo "$NODES"

# Step 3: For each node, unmount and remove the stale directory
for NODE in $NODES; do
    echo "Processing node: $NODE"
    
    # Force unmount the stale mount
    echo "  - Forcibly unmounting $MOUNT_PATH on $NODE..."
    ssh root@"$NODE" "umount -f '$MOUNT_PATH'" 2>/dev/null
    
    # Remove the directory
    echo "  - Removing directory $MOUNT_PATH on $NODE..."
    ssh root@"$NODE" "rm -rf '$MOUNT_PATH'" 2>/dev/null
done

# Step 4: Re-enable the storage
echo "Re-enabling Proxmox storage '$STORAGE_NAME'..."
pvesm set "$STORAGE_NAME" --disable 0
if [ $? -ne 0 ]; then
    echo "Error: Failed to re-enable storage '$STORAGE_NAME'. Please check the storage name and permissions."
    exit 1
fi

echo "Successfully updated the stale file mount for storage '$STORAGE_NAME'."
exit 0
