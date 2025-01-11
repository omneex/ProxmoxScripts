#!/bin/bash
#
# This script sets the CPU type and the number of cores for a range of virtual machines (VMs) within a Proxmox VE environment.
# By default, it will use the current CPU type unless specified.
#
# Usage:
# ./BulkSetCPUTypeCoreCount.sh <start_vm_id> <end_vm_id> <num_cores> [cpu_type]
#
# Arguments:
#   start_vm_id - The ID of the first VM to update.
#   end_vm_id - The ID of the last VM to update.
#   num_cores - The number of CPU cores to assign to each VM.
#   cpu_type - Optional. The CPU type to set for each VM. If not provided, the current CPU type will be retained.
#
# Example:
#   ./BulkSetCPUTypeCoreCount.sh 400 430 4
#   ./BulkSetCPUTypeCoreCount.sh 400 430 4 host

# Check if the required parameters are provided
if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
    echo "Usage: $0 <start_vm_id> <end_vm_id> <num_cores> [cpu_type]"
    exit 1
fi

# Assigning input arguments
START_VM_ID=$1
END_VM_ID=$2
NUM_CORES=$3
CPU_TYPE=${4:-}

# Loop to update CPU configuration for VMs in the specified range
for (( VMID=START_VM_ID; VMID<=END_VM_ID; VMID++ )); do
    # Check if the VM exists
    if qm status $VMID &>/dev/null; then
        echo "Updating CPU configuration for VM ID: $VMID"

        # Set the number of CPU cores
        qm set $VMID --cores $NUM_CORES

        # Set the CPU type if provided
        if [ -n "$CPU_TYPE" ]; then
            qm set $VMID --cpu $CPU_TYPE
            echo " - CPU type set to '$CPU_TYPE' for VM ID: $VMID."
        else
            echo " - CPU type retained for VM ID: $VMID."
        fi

        echo " - Number of cores set to $NUM_CORES for VM ID: $VMID."
    else
        echo "VM ID: $VMID does not exist. Skipping..."
    fi

done

echo "CPU configuration update process completed!"