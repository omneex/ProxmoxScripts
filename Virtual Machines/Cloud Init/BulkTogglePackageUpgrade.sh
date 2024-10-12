#!/bin/bash

# This script enables or disables automatic package upgrades for a range of virtual machines (VMs) within a Proxmox VE environment.
# It updates the Cloud-Init configuration for each VM to set or unset automatic package upgrades.
#
# Usage:
# ./ToggleAutoUpgrade.sh <start_vm_id> <end_vm_id> <enable|disable>
#
# Arguments:
#   start_vm_id - The ID of the first VM to update.
#   end_vm_id - The ID of the last VM to update.
#   enable|disable - Set to 'enable' to enable automatic upgrades, or 'disable' to disable them.
#
# Example:
#   ./ToggleAutoUpgrade.sh 400 430 enable
#   ./ToggleAutoUpgrade.sh 400 430 disable

# Check if the required parameters are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <start_vm_id> <end_vm_id> <enable|disable>"
    exit 1
fi

# Assigning input arguments
START_VM_ID=$1
END_VM_ID=$2
ACTION=$3

# Determine the appropriate Cloud-Init setting based on the action
if [ "$ACTION" == "enable" ]; then
    AUTO_UPGRADE_SETTING="1"
elif [ "$ACTION" == "disable" ]; then
    AUTO_UPGRADE_SETTING="0"
else
    echo "Invalid action: $ACTION. Use 'enable' or 'disable'."
    exit 1
fi

# Loop to update automatic package upgrade setting for VMs in the specified range
for (( VMID=START_VM_ID; VMID<=END_VM_ID; VMID++ )); do
    # Check if the VM exists
    if qm status $VMID &>/dev/null; then
        echo "Updating automatic package upgrade setting for VM ID: $VMID"

        # Set the automatic upgrade setting using Cloud-Init
        qm set $VMID --ciuser root --cipassword "" --set "packages_auto_upgrade=$AUTO_UPGRADE_SETTING"

        # Regenerate the Cloud-Init image
        qm cloudinit dump $VMID
        echo " - Automatic package upgrade set to '$ACTION' for VM ID: $VMID."
    else
        echo "VM ID: $VMID does not exist. Skipping..."
    fi

done

echo "Automatic package upgrade update process completed!"