#!/bin/bash

# This script retrieves the IP address of each virtual machine (VM) in the Proxmox VE cluster
# and appends this information to the notes field of the respective VM.
# If the VM does not have Cloud-Init enabled, it will attempt to scan the VLAN for the IP address based on the MAC address.
#
# Usage:
# ./UpdateVMNotesWithIP.sh

# Loop through all VMs in the cluster
VM_IDS=$(qm list | awk 'NR>1 {print $1}')
for VMID in $VM_IDS; do
    echo "Processing VM ID: $VMID"

    # Get the IP address of the VM using qm agent
    IP_ADDRESS=$(qm guest exec $VMID "ip -o -4 addr list eth0 | awk '{print \$4}' | cut -d/ -f1" 2>/dev/null)
    if [ -z "$IP_ADDRESS" ]; then
        echo " - Unable to retrieve IP address using Cloud-Init for VM ID: $VMID"
        
        # Get the MAC address of the VM
        MAC_ADDRESS=$(qm config $VMID | grep -E '^net\d+: ' | grep -oP 'mac=\K[^,]+')
        if [ -z "$MAC_ADDRESS" ]; then
            echo " - Unable to retrieve MAC address for VM ID: $VMID"
            continue
        fi

        echo " - Retrieved MAC address: $MAC_ADDRESS"

        # Get the VLAN or bridge the VM is connected to
        VLAN=$(qm config $VMID | grep -E '^net\d+: ' | grep -oP 'bridge=\K\S+')
        if [ -z "$VLAN" ]; then
            echo " - Unable to retrieve VLAN/bridge for VM ID: $VMID"
            continue
        fi

        echo " - Retrieved VLAN/bridge: $VLAN"

        # Ping scan the VLAN to find the IP address based on the MAC address
        IP_ADDRESS=$(nmap -sn -oG - $VLAN | grep -i "$MAC_ADDRESS" | awk '{print $2}')
        if [ -z "$IP_ADDRESS" ]; then
            echo " - Unable to determine IP address via VLAN scan for VM ID: $VMID"
            IP_ADDRESS="Could not determine IP address"
        else
            echo " - Retrieved IP address via VLAN scan: $IP_ADDRESS"
        fi
    else
        echo " - Retrieved IP address: $IP_ADDRESS"
    fi

    # Get the existing notes from the VM
    EXISTING_NOTES=$(qm config $VMID | grep -E '^notes:' | cut -d' ' -f2-)

    # Append the IP address to the notes field
    NEW_NOTES="$EXISTING_NOTES\nIP Address: $IP_ADDRESS"
    qm set $VMID --notes "$NEW_NOTES"
    echo " - Updated notes for VM ID: $VMID"
done

echo "VM notes update process completed!"