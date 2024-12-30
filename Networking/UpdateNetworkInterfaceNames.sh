#!/bin/bash
#
# UpdateInterfaceNames.sh
#
# This script updates /etc/network/interfaces to match new network interface names as found in `ip a`.
# It creates a backup, attempts to map old names to new names, and handles multiple occurrences
# of the same interface (e.g., bond-slaves).
#
# Usage:
#   ./UpdateInterfaceNames.sh
#
# No arguments are required.
#

###############################################################################
# CONFIG / CONSTANTS
###############################################################################

CONFIG_FILE="/etc/network/interfaces"
BACKUP_FILE="/etc/network/interfaces.bak-$(date +%Y%m%d%H%M%S)"

###############################################################################
# PRE-CHECKS
###############################################################################

# Ensure /etc/network/interfaces exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: $CONFIG_FILE not found. Exiting."
  exit 1
fi

# Backup the original file
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "Backed up '$CONFIG_FILE' to '$BACKUP_FILE'."

###############################################################################
# HELPER FUNCTIONS
###############################################################################

# 1. Replace all word-bound occurrences of $old_name with $new_name in $CONFIG_FILE
update_interface_names() {
  local old_name="$1"
  local new_name="$2"

  # We'll check whether the old_name even appears in the file
  if grep -q "\b${old_name}\b" "$CONFIG_FILE"; then
    # Replace occurrences
    sed -i "s/\b${old_name}\b/${new_name}/g" "$CONFIG_FILE"
    echo " - Updated interface name: $old_name => $new_name"
  else
    echo " - Skipping: '$old_name' not found in $CONFIG_FILE"
  fi
}

###############################################################################
# MAIN LOGIC
###############################################################################

declare -A interface_map
declare -A base_name_count

echo
echo "=== Scanning current interfaces via 'ip a' ==="

# We parse each line of `ip a` to find interface names
# Example lines typically look like:
# 2: enp0s3: <BROADCAST,MULTICAST,UP,LOWER_UP> ...
# We capture "enp0s3" in group #1.
while read -r line; do
  if [[ $line =~ ^[0-9]+:\ ([^:]+): ]]; then
    interface="${BASH_REMATCH[1]}"
    # Skip loopback, tunnels, or other special interfaces as needed:
    if [[ $interface == "lo" ]] || [[ $interface == *"tap"* ]] || [[ $interface == *"veth"* ]]; then
      continue
    fi
    
    # Attempt to derive a "base name" from the new name.
    # If your naming scheme is e.g., old=eth0, new=enp0s3, you might want a custom approach here.
    # Below is just an example removing "enp" or "np" to guess a base:
    base_name=$(echo "$interface" | sed -E 's/^en?p[0-9]//; s/[0-9]+$//')

    # If your old config had "eth0" or "bond0", you might want to do more logic here.
    # The key is that we try to match old_name => new_name.
    
    # We'll store the first new interface that corresponds to each base_name
    # to avoid collisions if multiple new interfaces share the same base_name.
    if [ -n "$base_name" ]; then
      if [ -z "${interface_map[$base_name]}" ]; then
        interface_map[$base_name]="$interface"
        # Keep track of how many times each base_name was encountered
        base_name_count[$base_name]=1
      else
        # If we already have a mapping for the same base_name, increment count
        count=${base_name_count[$base_name]}
        new_count=$((count + 1))
        base_name_count[$base_name]=$new_count
        # Potentially skip or handle collisions. For now, we do nothing special.
        echo "WARNING: Multiple new interfaces share the base name '$base_name' => $interface and ${interface_map[$base_name]}"
      fi
    fi
  fi
done < <(ip a)

# If we didn't find any new interfaces, exit
if [ ${#interface_map[@]} -eq 0 ]; then
  echo "No usable network interfaces found via 'ip a' (excluding lo/tap/veth). Exiting."
  exit 0
fi

# Now we attempt to update /etc/network/interfaces
echo
echo "=== Updating $CONFIG_FILE based on derived mappings ==="

for base_name in "${!interface_map[@]}"; do
  old_name="$base_name"
  new_name="${interface_map[$base_name]}"

  # If old_name and new_name are the same, skip to avoid no-op
  if [ "$old_name" == "$new_name" ]; then
    continue
  fi

  # Replace occurrences of old_name with new_name
  update_interface_names "$old_name" "$new_name"
done

echo
echo "=== Done! ==="
echo "Your network interfaces file has been updated."
echo "Original backup: $BACKUP_FILE"
echo "Please review $CONFIG_FILE for correctness, then manually restart networking."
echo
