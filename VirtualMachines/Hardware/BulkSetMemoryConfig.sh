#!/bin/bash
#
# This script sets the amount of memory allocated to a range of virtual machines (VMs) within a Proxmox VE environment.
#
# Usage:
# ./SetMemoryConfig.sh <start_vm_id> <end_vm_id> <memory_size>
#
# Arguments:
#   start_vm_id - The ID of the first VM to update.
#   end_vm_id - The ID of the last VM to update.
#   memory_size - The amount of memory (in MB) to allocate to each VM.
#
# Example:
#   ./SetMemoryConfig.sh 400 430 8192

# Check if the required parameters are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <start_vm_id> <end_vm_id> <memory_size>"
    exit 1
fi

# Assigning input arguments
START_VM_ID=$1
END_VM_ID=$2
MEMORY_SIZE=$3

# Loop to update memory allocation for VMs in the specified range
for (( VMID=START_VM_ID; VMID<=END_VM_ID; VMID++ )); do
    # Check if the VM exists
    if qm status $VMID &>/dev/null; then
        echo "Updating memory allocation for VM ID: $VMID"

        # Set the memory size
        qm set $VMID --memory $MEMORY_SIZE
        echo " - Memory allocated: ${MEMORY_SIZE}MB for VM ID: $VMID."
    else
        echo "VM ID: $VMID does not exist. Skipping..."
    fi

done

echo "Memory allocation update process completed!"