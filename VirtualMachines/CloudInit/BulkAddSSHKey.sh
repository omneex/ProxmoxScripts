#!/bin/bash
#
# This script adds an SSH public key to a range of virtual machines (VMs) within a Proxmox VE environment.
# It appends a new SSH public key for each VM and regenerates the Cloud-Init image to apply the changes.
#
# Usage:
# ./AddSSHKey.sh <start_vm_id> <end_vm_id> <ssh_public_key>
#
# Arguments:
#   start_vm_id - The ID of the first VM to update.
#   end_vm_id - The ID of the last VM to update.
#   ssh_public_key - The SSH public key to be added to the VM.
#
# Example:
#   ./AddSSHKey.sh 400 430 "ssh-rsa AAAAB3Nza... user@host"

# Check if the minimum required parameters are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <start_vm_id> <end_vm_id> <ssh_public_key>"
    exit 1
fi

# Assigning input arguments
START_VM_ID=$1
END_VM_ID=$2
SSH_PUBLIC_KEY=$3

# Loop to add SSH public key for VMs in the specified range
for (( VMID=START_VM_ID; VMID<=END_VM_ID; VMID++ )); do
    # Check if the VM exists
    if qm status $VMID &>/dev/null; then
        echo "Adding SSH public key to VM ID: $VMID"

        # Append the SSH public key to the existing keys using Cloud-Init
        TEMP_FILE=$(mktemp)
        qm cloudinit get $VMID ssh-authorized-keys > "$TEMP_FILE"
        echo "$SSH_PUBLIC_KEY" >> "$TEMP_FILE"
        qm set $VMID --sshkeys "$TEMP_FILE"
        rm "$TEMP_FILE"

        # Regenerate the Cloud-Init image
        qm cloudinit dump $VMID
        echo " - SSH public key appended for VM ID: $VMID."
    else
        echo "VM ID: $VMID does not exist. Skipping..."
    fi

done

echo "SSH public key addition process completed!"