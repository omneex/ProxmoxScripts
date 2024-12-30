#!/bin/bash
#
# UpdateVMNotesWithIP.sh
#
# This script retrieves the IP address of each QEMU virtual machine (VM) in the Proxmox VE cluster
# and updates or appends this information to the notes field of the respective VM.
# If the VM does not have Cloud-Init or Qemu Guest Agent returning an IP, it will attempt
# to scan the network for the IP based on the MAC address.
#
# Additionally, if the notes field already has "IP Address: ...", that line will be updated
# with the new IP, rather than adding a duplicate line.
#
# Usage:
#   ./UpdateVMNotesWithIP.sh

# Loop through all QEMU VMs in the cluster
VM_IDS=$(qm list | awk 'NR>1 {print $1}')

for VMID in $VM_IDS; do
    echo "Processing QEMU VM ID: $VMID"

    # Try to retrieve the IP address of the VM with the Qemu Guest Agent
    # This typically requires 'guest agent' configured and the VM OS supporting it
    IP_ADDRESS=$(qm guest exec "$VMID" "ip -o -4 addr list eth0 | awk '{print \$4}' | cut -d/ -f1" 2>/dev/null)

    if [ -z "$IP_ADDRESS" ]; then
        echo " - Unable to retrieve IP address via guest agent for VM $VMID."

        # Get the MAC address of the VM (assuming net0)
        MAC_ADDRESS=$(qm config "$VMID" | grep -E '^net\d+: ' | grep -oP 'mac=\K[^,]+')
        if [ -z "$MAC_ADDRESS" ]; then
            echo " - Could not retrieve MAC address for VM $VMID. Skipping."
            continue
        fi
        echo " - Retrieved MAC address: $MAC_ADDRESS"

        # Identify the bridge or VLAN
        VLAN=$(qm config "$VMID" | grep -E '^net\d+: ' | grep -oP 'bridge=\K\S+')
        if [ -z "$VLAN" ]; then
            echo " - Unable to retrieve VLAN/bridge info for VM $VMID. Skipping."
            continue
        fi
        echo " - Retrieved VLAN/bridge: $VLAN"

        # Ping scan the VLAN to find IP by MAC address (requires nmap or similar)
        # This step depends heavily on the environment; adapt as needed.
        IP_ADDRESS=$(nmap -sn -oG - "$VLAN" 2>/dev/null | grep -i "$MAC_ADDRESS" | awk '{print $2}')
        if [ -z "$IP_ADDRESS" ]; then
            IP_ADDRESS="Could not determine IP address"
            echo " - Unable to determine IP via VLAN scan for VM $VMID."
        else
            echo " - Retrieved IP address via VLAN scan: $IP_ADDRESS"
        fi
    else
        echo " - Retrieved IP address via guest agent: $IP_ADDRESS"
    fi

    # Retrieve existing notes
    # Notes are stored in the config as a single line, though you can embed \n for new lines.
    EXISTING_NOTES=$(qm config "$VMID" | sed -n 's/^notes: //p')

    # If there's no existing notes line, we'll start from blank
    if [ -z "$EXISTING_NOTES" ]; then
        EXISTING_NOTES=""
    fi

    # Check if there's an "IP Address:" line already
    if echo "$EXISTING_NOTES" | grep -q "^IP Address:"; then
        # Update that line to the new IP
        UPDATED_NOTES=$(echo "$EXISTING_NOTES" | sed -E "s|^IP Address:.*|IP Address: $IP_ADDRESS|")
    else
        # Append the new line
        # Use '\n' to add a new line in the notes
        UPDATED_NOTES="${EXISTING_NOTES}\nIP Address: $IP_ADDRESS"
    fi

    # Update the VM notes
    qm set "$VMID" --notes "$UPDATED_NOTES"
    echo " - Updated notes for VM ID: $VMID"
    echo
done

echo "=== QEMU VM notes update process completed! ==="
