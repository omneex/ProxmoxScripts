#!/bin/bash

# This script updates the /etc/network/interfaces file to match the new network interface names as found in the output of `ip a`.
# It backs up the original interfaces file, updates all instances of old interface names with the new ones,
# and handles multiple occurrences in a single line, such as bond-slaves.

# Usage:
# ./UpdateInterfaceNames.sh
# No arguments are required.

# Backup the original interfaces file
CONFIG_FILE="/etc/network/interfaces"
BACKUP_FILE="/etc/network/interfaces.bak"

cp $CONFIG_FILE $BACKUP_FILE

# Function to update interface names in the configuration file
update_interface_names() {
    local old_name=$1
    local new_name=$2

    # Replace all occurrences of the old name with the new name
    sed -i "s/\b$old_name\b/$new_name/g" $CONFIG_FILE
}

# Get a list of the current network device names from 'ip a'
declare -A new_interfaces
while read -r line; do
    if [[ $line =~ ^[0-9]+:\ ([^:]+): ]]; then
        interface="${BASH_REMATCH[1]}"
        if [[ $interface != "lo" ]]; then
            base_name=$(echo "$interface" | sed 's/np[0-9]//')
            new_interfaces[$base_name]=$interface
        fi
    fi
done < <(ip a)

# Update the /etc/network/interfaces file
for old_name in "${!new_interfaces[@]}"; do
    new_name=${new_interfaces[$old_name]}
    update_interface_names "$old_name" "$new_name"
    echo "Updated $old_name to $new_name"
done

echo "Network interfaces have been updated successfully."

# Suggest reviewing the changes and manually restarting networking
echo "Please check $CONFIG_FILE for accuracy."
echo "Please manually restart the network service or the interfaces to apply changes."
