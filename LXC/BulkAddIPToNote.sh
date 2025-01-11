#!/bin/bash
#
# UpdateNotesWithIP.sh
#
# This script retrieves the IP address of each LXC container in the local Proxmox VE node
# and updates/appends this information to the description field of the respective container.
# If the container does not provide an IP via 'pct exec', it attempts to scan the network
# for the IP based on the container's MAC address.
#
# If the description already contains an "IP Address:" line, that line is updated; otherwise,
# the IP Address line is appended.
#
# Usage:
#   ./UpdateNotesWithIP.sh
#
# Example:
#   # Updates all local LXC containers' descriptions with the discovered IP address
#   ./UpdateNotesWithIP.sh
#

source "$UTILITIES"

###############################################################################
# Environment Checks
###############################################################################
check_root
check_proxmox

###############################################################################
# Dependency Checks
###############################################################################
install_or_prompt "nmap"

###############################################################################
# Main Logic
###############################################################################
readarray -t containerIds < <( pct list | awk 'NR>1 {print $1}' )

for ctId in "${containerIds[@]}"; do
  echo "Processing LXC container ID: \"$ctId\""

  ipAddress=$(pct exec "$ctId" -- bash -c "ip -o -4 addr list eth0 | awk '{print \$4}' | cut -d/ -f1" 2>/dev/null)
  if [ -z "$ipAddress" ]; then
    echo " - Unable to retrieve IP address via pct exec for container \"$ctId\"."
    macAddress=$(pct config "$ctId" | grep -E '^net[0-9]+: ' | grep -oP 'hwaddr=\K[^,]+')
    if [ -z "$macAddress" ]; then
      echo " - Could not retrieve MAC address for container \"$ctId\". Skipping."
      continue
    fi
    vlan=$(pct config "$ctId" | grep -E '^net[0-9]+: ' | grep -oP 'bridge=\K\S+')
    if [ -z "$vlan" ]; then
      echo " - Unable to retrieve VLAN/bridge info for container \"$ctId\". Skipping."
      continue
    fi
    ipAddress=$(nmap -sn -oG - "$vlan" 2>/dev/null | grep -i "$macAddress" | awk '{print $2}')
    if [ -z "$ipAddress" ]; then
      ipAddress="Could not determine IP address"
      echo " - Unable to determine IP via VLAN scan for container \"$ctId\"."
    else
      echo " - Retrieved IP address via VLAN scan: \"$ipAddress\""
    fi
  else
    echo " - Retrieved IP address via pct exec: \"$ipAddress\""
  fi

  existingNotes=$(pct config "$ctId" | sed -n 's/^notes: //p')
  if [ -z "$existingNotes" ]; then
    existingNotes=""
  fi

  if echo "$existingNotes" | grep -q "^IP Address:"; then
    updatedNotes=$(echo "$existingNotes" | sed -E "s|^IP Address:.*|IP Address: $ipAddress|")
  else
    updatedNotes="${existingNotes}<br/>IP Address: $ipAddress"
  fi

  pct set "$ctId" --description "$updatedNotes"
  echo " - Updated description for container \"$ctId\""
  echo
done

echo "=== LXC container description update process completed! ==="

prompt_keep_installed_packages
