#!/bin/bash

# This script configures network interfaces for bonding and VLAN bridging on a Linux system.
# It checks if the necessary inputs are provided, creates configuration entries for a specified bond and VLAN ID,
# and inserts these entries into the network configuration file in a sorted order based on interface names.
# The script ensures that duplicate entries are not added and it prompts the user to manually restart the network services
# to apply changes.
#
# Usage:
# ./AddNetworkBond.sh <bond_base> <vlan_id>
# Where:
#   bond_base - The base name of the network bond (e.g., bond0)
#   vlan_id - The VLAN ID to configure with the bond

# Check if required inputs are provided
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <bond_base> <vlan_id>"
    exit 1
fi

BOND_BASE=$1
VLAN_ID=$2
BOND_NAME="${BOND_BASE}.${VLAN_ID}"
VMBR_NAME="vmbr${VLAN_ID}"

# File to modify
CONFIG_FILE="/etc/network/interfaces"

# Function to insert configuration in sorted order
insert_sorted_config() {
    local insert_name=$1
    local insert_config=$2
    local config_type=$3

    local pattern="iface ${config_type}[0-9]+"
    local config_block=$(awk "/^auto $pattern/,/^$/" RS= $CONFIG_FILE)

    if echo "$config_block" | grep -q "^auto $insert_name$"; then
        echo "$insert_name already exists in $CONFIG_FILE"
        return 1
    fi

    local sorted_block=$(echo -e "$config_block\nauto $insert_name\n$insert_config" | sort -V)

    # Recreate the config section with the new entry
    awk -v pat="^auto $pattern$" -v sorted="$sorted_block" '
    /^auto '"$config_type"'[0-9]+/,/^$/ { if (!p) {print sorted; p=1}; next }
    { print }
    ' RS= ORS='\n\n' $CONFIG_FILE > $CONFIG_FILE.tmp && mv $CONFIG_FILE.tmp $CONFIG_FILE
}

# Bond and VMBR configuration texts
BOND_CONFIG="auto $BOND_NAME\niface $BOND_NAME inet manual\n    vlan-raw-device $BOND_BASE"
VMBR_CONFIG="auto $VMBR_NAME\niface $VMBR_NAME inet manual\n    bridge_ports $BOND_NAME\n    bridge_stp off\n    bridge_fd 0"

# Insert bond configuration in sorted order
insert_sorted_config "$BOND_NAME" "$BOND_CONFIG" "$BOND_BASE"

# Insert vmbr configuration in sorted order
insert_sorted_config "$VMBR_NAME" "$VMBR_CONFIG" "vmbr"

echo "Configuration potentially added. Please check $CONFIG_FILE for accuracy."

# Suggest restarting networking manually
echo "Please manually restart the network service or the interfaces to apply changes."
