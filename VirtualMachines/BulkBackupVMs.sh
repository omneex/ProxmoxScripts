#!/bin/bash

# This script backs up a range of VMs within a Proxmox environment to a specified storage.
#
# Usage:
# ./BackupVMs.sh <start_vm_id> <end_vm_id> <storage>
#
# Arguments:
#   start_vm_id - The ID of the first VM to back up.
#   end_vm_id - The ID of the last VM to back up.
#   storage - The target storage location for the backup.
#
# Example:
#   ./BackupVMs.sh 500 525 local

# Check if the required parameters are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <start_vm_id> <end_vm_id> <storage>"
    exit 1
fi

# Assigning input arguments
START_VM_ID=$1
END_VM_ID=$2
STORAGE=$3

# Loop through the VM IDs
for (( VMID=START_VM_ID; VMID<=END_VM_ID; VMID++ )); do
    # Check if the VM exists
    if qm status $VMID &>/dev/null; then
        echo "Backing up VM ID: $VMID to storage: $STORAGE"

        # Perform the backup
        if vzdump $VMID --storage $STORAGE --mode snapshot; then
            echo " - Successfully backed up VM ID: $VMID."
        else
            echo " - Failed to back up VM ID: $VMID."
        fi
    else
        echo "VM ID: $VMID does not exist. Skipping..."
    fi

done

echo "Backup process complete."