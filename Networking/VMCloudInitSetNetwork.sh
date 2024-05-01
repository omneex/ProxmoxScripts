#!/bin/bash

# This script is designed to update the Cloud-Init network settings for a range of virtual machines (VMs)
# in a Proxmox VE environment. It allows you to set IP addresses, CIDR, and gateway for VMs within a specified range.
# Each VM's network settings are updated based on a sequential IP address calculation.
#
# Usage:
# ./VMCloudInitSetNetwork.sh <start_vm_id> <end_vm_id> <base_ip> <start_ip_octet> <cidr> <gateway>
#
# Arguments:
#   start_vm_id - The starting VM ID for the range.
#   end_vm_id - The ending VM ID for the range.
#   base_ip - The base IP address for Cloud-Init.
#   start_ip_octet - The starting octet to be appended to the base IP address.
#   cidr - The CIDR notation for the network mask.
#   gateway - The gateway IP address for the network.
#
# Example:
#   ./VMCloudInitSetNetwork.sh 100 110 192.168.100. 50 24 192.168.100.1

# Check if all required parameters are provided
if [ "$#" -ne 6 ]; then
    echo "Usage: $0 <start_vm_id> <end_vm_id> <base_ip> <start_ip_octet> <cidr> <gateway>"
    exit 1
fi

# Assigning input arguments
START_VM_ID=$1
END_VM_ID=$2
BASE_IP=$3
START_IP_OCTET=$4
CIDR=$5
GATEWAY=$6

# Loop through the specified range of VM IDs
for (( VM_ID=$START_VM_ID; VM_ID<=$END_VM_ID; VM_ID++ )); do
    # Calculate the current IP octet
    CURRENT_IP_OCTET=$((START_IP_OCTET + VM_ID - START_VM_ID))
    VM_IP="${BASE_IP}${CURRENT_IP_OCTET}"

    # Update Cloud-Init network settings for the VM
    echo "Updating VM ID $VM_ID with IP $VM_IP"
    qm set $VM_ID --ipconfig0 ip=$VM_IP/$CIDR,gw=$GATEWAY

    # Optional: Check for errors and report
    if [ $? -ne 0 ]; then
        echo "Failed to update network settings for VM ID $VM_ID"
    else
        echo "Network settings updated for VM ID $VM_ID"
    fi
done

echo "Network settings update completed for VMs from ID $START_VM_ID to $END_VM_ID."
