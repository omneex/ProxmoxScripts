#!/bin/bash
#
# UpdateLXCNotesWithIP.sh
#
# This script retrieves the IP address of each LXC container in the Proxmox VE cluster
# and updates/appends this information to the notes field of the respective container.
# If the container does not provide an IP via 'pct exec', it attempts
# to scan the network for the IP based on the container's MAC address.
#
# If the notes already contain an "IP Address:" line, that line is updated; otherwise,
# the IP Address line is appended.
#
# Usage:
#   ./UpdateLXCNotesWithIP.sh
#
# Changes:
# V1.1: Fixed mixup between pct and qm, changed to description instead of notes
#

# Loop through all LXC containers in the cluster
CT_IDS=$(pct list | awk 'NR>1 {print $1}')

for CTID in $CT_IDS; do
    echo "Processing LXC container ID: $CTID"

    # Attempt to retrieve IP with 'pct exec'
    # We'll try "ip -o -4 addr list eth0" inside the container
    IP_ADDRESS=$(pct exec "$CTID" -- bash -c "ip -o -4 addr list eth0 | awk '{print \$4}' | cut -d/ -f1" 2>/dev/null)

    if [ -z "$IP_ADDRESS" ]; then
        echo " - Unable to retrieve IP address via pct exec for container $CTID."

        # Retrieve MAC address from container config
        # Typically in the format: net0: name=eth0,bridge=vmbr0,hwaddr=DE:AD:BE:EF:00:01
        MAC_ADDRESS=$(pct config "$CTID" | grep -E '^net\d+: ' | grep -oP 'hwaddr=\K[^,]+')
        if [ -z "$MAC_ADDRESS" ]; then
            echo " - Could not retrieve MAC address for container $CTID. Skipping."
            continue
        fi
        echo " - Retrieved MAC address: $MAC_ADDRESS"

        # Identify the bridge or VLAN (bridge=vmbrX)
        VLAN=$(pct config "$CTID" | grep -E '^net\d+: ' | grep -oP 'bridge=\K\S+')
        if [ -z "$VLAN" ]; then
            echo " - Unable to retrieve VLAN/bridge info for container $CTID. Skipping."
            continue
        fi
        echo " - Retrieved VLAN/bridge: $VLAN"

        # Attempt to find IP with nmap scan
        IP_ADDRESS=$(nmap -sn -oG - "$VLAN" 2>/dev/null | grep -i "$MAC_ADDRESS" | awk '{print $2}')
        if [ -z "$IP_ADDRESS" ]; then
            IP_ADDRESS="Could not determine IP address"
            echo " - Unable to determine IP via VLAN scan for container $CTID."
        else
            echo " - Retrieved IP address via VLAN scan: $IP_ADDRESS"
        fi
    else
        echo " - Retrieved IP address via pct exec: $IP_ADDRESS"
    fi

    # Get existing notes from the container config
    EXISTING_NOTES=$(pct config "$CTID" | sed -n 's/^notes: //p')

    if [ -z "$EXISTING_NOTES" ]; then
        EXISTING_NOTES=""
    fi

    # Check if there's an "IP Address:" line already
    if echo "$EXISTING_NOTES" | grep -q "^IP Address:"; then
        # Update that line
        UPDATED_NOTES=$(echo "$EXISTING_NOTES" | sed -E "s|^IP Address:.*|IP Address: $IP_ADDRESS|")
    else
        # Append new line
        UPDATED_NOTES="${EXISTING_NOTES}<br/>IP Address: $IP_ADDRESS"
    fi

    # Update container notes
    pct set "$CTID" --description  "$UPDATED_NOTES"
    echo " - Updated description  for container $CTID"
    echo
done

echo "=== LXC container description  update process completed! ==="
