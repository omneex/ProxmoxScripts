#!/bin/bash
#
# This script is designed to automate the process of changing the network bridge configuration for a range of virtual machines (VMs) on a Proxmox VE cluster.
# It iterates through a specified range of VM IDs, modifying their configuration files to replace an old network bridge with a new one if present.
# The script checks for the existence of each VM's configuration file and ensures that changes are only made where applicable.
#
# Usage:
# ./VMConfigChangeNetwork.sh <start_id> <end_id> <hostname> <current_network> <new_network>
# Where:
#   start_id - The starting VM ID in the range to be processed.
#   end_id - The ending VM ID in the range to be processed.
#   hostname - The hostname of the Proxmox node where the VMs are hosted.
#   current_network - The current network bridge (e.g., vmbr0) to be replaced.
#   new_network - The new network bridge (e.g., vmbr1) to use in the configuration.

# Check if required inputs are provided
if [ $# -lt 5 ]; then
    echo "Usage: $0 <start_id> <end_id> <hostname> <current_network> <new_network>"
    exit 1
fi

START_ID=$1
END_ID=$2
HOST_NAME=$3
CURRENT_NETWORK=$4
NEW_NETWORK=$5

# Loop through the VM IDs
for VMID in $(seq $START_ID $END_ID); do
    CONFIG_FILE="/etc/pve/nodes/${HOST_NAME}/qemu-server/${VMID}.conf"

    # Check if the VM config file exists
    if [ -f "$CONFIG_FILE" ]; then
        echo "Processing VM ID: $VMID"

        # Check and replace the network bridge
        if grep -q "$CURRENT_NETWORK" "$CONFIG_FILE"; then
            sed -i "s/$CURRENT_NETWORK/$NEW_NETWORK/g" "$CONFIG_FILE"
            echo " - Network bridge changed from $CURRENT_NETWORK to $NEW_NETWORK."
        else
            echo " - $CURRENT_NETWORK not found in network configuration. No changes made."
        fi
    else
        echo "VM ID: $VMID does not exist. Skipping..."
    fi
done
