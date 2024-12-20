#!/bin/bash

# This script updates the network bridge in the configuration files of a range of VMs within a Proxmox environment.
#
# Usage:
# ./UpdateVMBridge.sh <start_vm_id> <end_vm_id> <old_bridge> <new_bridge>
#
# Arguments:
#   start_vm_id - The ID of the first VM to update.
#   end_vm_id - The ID of the last VM to update.
#   old_bridge - The old network bridge to be replaced.
#   new_bridge - The new network bridge to replace the old one.
#
# Example:
#   ./UpdateVMBridge.sh 500 525 vmbr1 vmbr811

# Check if the required parameters are provided
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <start_vm_id> <end_vm_id> <old_bridge> <new_bridge>"
    exit 1
fi

# Assigning input arguments
START_VM_ID=$1
END_VM_ID=$2
OLD_BRIDGE=$3
NEW_BRIDGE=$4

# Loop through the VM IDs
for (( VMID=START_VM_ID; VMID<=END_VM_ID; VMID++ )); do
    # Define the config file path
    CONFIG_FILE="/etc/pve/nodes/IHK12/qemu-server/${VMID}.conf"

    # Check if the VM config file exists
    if [ -f "$CONFIG_FILE" ]; then
        echo "Processing VM ID: $VMID"

        # Replace the old bridge with the new bridge in the network configuration
        if sed -i "s/\<$OLD_BRIDGE\>/$NEW_BRIDGE/g" "$CONFIG_FILE"; then
            echo " - Network bridge changed from $OLD_BRIDGE to $NEW_BRIDGE."
        else
            echo " - Failed to update network bridge for VM ID: $VMID"
        fi
    else
        echo "VM ID: $VMID does not exist. Skipping..."
    fi

done

echo "Bridge update process complete."