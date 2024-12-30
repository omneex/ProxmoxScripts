#!/bin/bash
#
# This script updates the IP addresses of a range of virtual machines (VMs) within a Proxmox VE environment.
# It assigns each VM a unique static IP, incrementing from a starting IP address, updates their network bridge configuration,
# and regenerates the Cloud-Init image to apply the changes.
#
# Usage:
# ./UpdateVMIPs.sh <start_vm_id> <end_vm_id> <start_ip/cidr> <bridge> [gateway]
#
# Arguments:
#   start_vm_id - The ID of the first VM to update.
#   end_vm_id - The ID of the last VM to update.
#   start_ip/cidr - The new IP address and subnet mask of the VM
#   bridge - The network bridge to be used for the VMs.
#   gateway - Optional. The gateway for the IP configuration
#
# Example:
#   ./UpdateVMIPs.sh 400 430 192.168.1.50/24 vmbr0 192.168.1.1
#   ./UpdateVMIPs.sh 400 430 192.168.1.50/24 vmbr0 # Without specifying a gateway

# Check if the minimum required parameters are provided
if [ "$#" -lt 4 ]; then
    echo "Usage: $0 <start_vm_id> <end_vm_id> <start_ip/cidr> <bridge> [gateway]"
    exit 1
fi

# Assigning input arguments
START_VM_ID=$1
END_VM_ID=$2
START_IP_CIDR=$3
BRIDGE=$4  # Network bridge, required
GATEWAY=${5:-}  # Optional gateway, default to an empty string if not provided

# Extract the IP address and CIDR from the start_ip/cidr
IFS='/' read -r START_IP SUBNET_MASK <<< "$START_IP_CIDR"

# Convert IP address to an integer
ip_to_int() {
    local a b c d
    IFS=. read -r a b c d <<< "$1"
    echo "$((a * 256 ** 3 + b * 256 ** 2 + c * 256 + d))"
}

# Convert integer to IP address
int_to_ip() {
    local ip
    ip=$(printf "%d.%d.%d.%d" "$((($1 >> 24) & 255))" "$((($1 >> 16) & 255))" "$((($1 >> 8) & 255))" "$((($1 & 255))")
    echo "$ip"
}

# Get the starting IP as an integer
START_IP_INT=$(ip_to_int "$START_IP")

# Loop to update IPs and network bridge for VMs in the specified range
for (( VMID=START_VM_ID; VMID<=END_VM_ID; VMID++ )); do
    # Increment the IP address
    CURRENT_IP_INT=$((START_IP_INT + VMID - START_VM_ID))
    NEW_IP=$(int_to_ip "$CURRENT_IP_INT")

    # Check if the VM exists
    if qm status $VMID &>/dev/null; then
        echo "Updating VM ID: $VMID with IP: $NEW_IP"

        # Set the static IP, subnet mask, and gateway using Cloud-Init
        qm set $VMID --ipconfig0 ip=${NEW_IP}/${SUBNET_MASK},gw=${GATEWAY}

        # Set the network bridge
        qm set $VMID --net0 virtio,bridge=$BRIDGE

        # Regenerate the Cloud-Init image
        qm cloudinit dump $VMID
        echo " - Cloud-Init image regenerated for VM ID: $VMID."
    else
        echo "VM ID: $VMID does not exist. Skipping..."
    fi

done

echo "IP update process completed!"