#!/bin/bash

# This script creates a High Availability (HA) group in the Proxmox VE cluster and adds the specified VMs to the group.
#
# Usage:
# ./CreateHAGroup.sh <group_name> <vm_id_1> [<vm_id_2> ... <vm_id_n>]

# Check if at least two arguments are provided (group name and at least one VM ID)
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <group_name> <vm_id_1> [<vm_id_2> ... <vm_id_n>]"
    exit 1
fi

# Assign the group name and shift to get the list of VM IDs
GROUP_NAME=$1
shift
VM_IDS=($@)

# Create the HA group
pvesh create /cluster/ha/groups --group $GROUP_NAME --comment "HA group created by script"
if [ $? -ne 0 ]; then
    echo "Failed to create HA group: $GROUP_NAME"
    exit 1
fi

echo "HA group '$GROUP_NAME' created successfully."

# Loop through each VM ID and add it to the HA group
for VMID in "${VM_IDS[@]}"; do
    echo "Adding VM ID: $VMID to HA group: $GROUP_NAME"
    pvesh create /cluster/ha/resources --sid "vm:$VMID" --group $GROUP_NAME
    if [ $? -eq 0 ]; then
        echo " - VM ID: $VMID added to HA group: $GROUP_NAME."
    else
        echo " - Failed to add VM ID: $VMID to HA group: $GROUP_NAME."
    fi
done

echo "HA group setup process completed!"