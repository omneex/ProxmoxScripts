#!/bin/bash
#
# This script unmounts all ISO images from the CD/DVD drives for a range of virtual machines (VMs) within a Proxmox VE environment.
#
# Usage:
# ./UnmountISOs.sh <start_vm_id> <end_vm_id>
#
# Arguments:
#   start_vm_id - The ID of the first VM to update.
#   end_vm_id - The ID of the last VM to update.
#
# Example:
#   ./UnmountISOs.sh 400 430

# Check if the required parameters are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <start_vm_id> <end_vm_id>"
    exit 1
fi

# Assigning input arguments
START_VM_ID=$1
END_VM_ID=$2

# Loop to unmount ISOs for VMs in the specified range
for (( VMID=START_VM_ID; VMID<=END_VM_ID; VMID++ )); do
    # Check if the VM exists
    if qm status $VMID &>/dev/null; then
        echo "Unmounting ISOs for VM ID: $VMID"

        # Get all CD/DVD drives for the VM
        DRIVES=$(qm config $VMID | grep -oP '(?<=^\S+\s)(ide\d+|sata\d+|scsi\d+|virtio\d+):\s.*media=cdrom')

        # Loop through each drive and unmount the ISO
        while read -r DRIVE; do
            DRIVE_NAME=$(echo "$DRIVE" | awk -F: '{print $1}')
            if [ -n "$DRIVE_NAME" ]; then
                qm set $VMID --$DRIVE_NAME none,media=cdrom
                echo " - ISO unmounted for drive $DRIVE_NAME of VM ID: $VMID."
            fi
        done <<< "$DRIVES"
    else
        echo "VM ID: $VMID does not exist. Skipping..."
    fi

done

echo "ISO unmount process completed!"