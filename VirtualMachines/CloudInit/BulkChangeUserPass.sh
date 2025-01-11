#!/bin/bash
#
# This script updates the Cloud-Init username and password for a range of virtual machines (VMs) within a Proxmox VE environment.
# It allows you to set a new username (optional) and password (required) for each VM and regenerates the Cloud-Init image to apply the changes.
#
# Usage:
# ./BulkChangeUserPass.sh <start_vm_id> <end_vm_id> <password> [username]
#
# Arguments:
#   start_vm_id - The ID of the first VM to update.
#   end_vm_id - The ID of the last VM to update.
#   password - The new password for the VM.
#   username - Optional. The new username for the VM. If not provided, the existing username will be used.
#
# Example:
#   ./BulkChangeUserPass.sh 400 430 myNewPassword newuser
#   ./BulkChangeUserPass.sh 400 430 myNewPassword # Without specifying a username

# Check if the minimum required parameters are provided
if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <start_vm_id> <end_vm_id> <password> [username]"
    exit 1
fi

# Assigning input arguments
START_VM_ID=$1
END_VM_ID=$2
PASSWORD=$3
USERNAME=${4:-}  # Optional username, default to an empty string if not provided

# Loop to update Cloud-Init username and password for VMs in the specified range
for (( VMID=START_VM_ID; VMID<=END_VM_ID; VMID++ )); do
    # Check if the VM exists
    if qm status $VMID &>/dev/null; then
        echo "Updating Cloud-Init settings for VM ID: $VMID"

        # Set the password using Cloud-Init
        qm set $VMID --ciuser "${USERNAME}" --cipassword "$PASSWORD"

        # Regenerate the Cloud-Init image
        qm cloudinit dump $VMID
        echo " - Cloud-Init username and password updated for VM ID: $VMID."
    else
        echo "VM ID: $VMID does not exist. Skipping..."
    fi

done

echo "Cloud-Init user and password update process completed!"