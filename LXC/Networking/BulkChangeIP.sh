#!/bin/bash
#
# BulkChangeLXCIPs.sh
#
# This script automates changing the IP addresses of a series of existing LXC containers on Proxmox VE.
# It increments through a specified number of containers, starting from a given container ID, and
# assigns sequential IP addresses based on a starting IP/CIDR. An optional gateway can also be set.
#
# Usage:
#   ./BulkChangeLXCIPs.sh <start_ct_id> <num_cts> <start_ip/cidr> <bridge> [gateway]
#
# Arguments:
#   start_ct_id    - The ID of the first container to update (e.g., 400).
#   num_cts        - How many containers to update (e.g., 5).
#   start_ip/cidr  - The new IP address and subnet mask for the first container (e.g., 192.168.1.50/24).
#   bridge         - The bridge to be used (e.g., vmbr0).
#   gateway        - Optional. The gateway for the IP configuration. If not provided, none is set.
#
# Example:
#   ./BulkChangeLXCIPs.sh 400 5 192.168.1.50/24 vmbr0 192.168.1.1
#   This will update containers 400..404 with IPs 192.168.1.50..54/24, using vmbr0 and gateway 192.168.1.1
#
#   ./BulkChangeLXCIPs.sh 400 5 192.168.1.50/24 vmbr0
#   Same as above, but does not set a gateway.

###############################################################################
# 1. INPUT VALIDATION
###############################################################################

if [ "$#" -lt 4 ]; then
  echo "Usage: $0 <start_ct_id> <num_cts> <start_ip/cidr> <bridge> [gateway]"
  exit 1
fi

START_CT_ID="$1"
NUM_CTS="$2"
START_IP_CIDR="$3"
BRIDGE="$4"
GATEWAY="${5:-}"  # Optional gateway, empty if not provided

# Extract the IP address and CIDR from the start_ip/cidr
IFS='/' read -r START_IP SUBNET_MASK <<< "$START_IP_CIDR"

# Basic validation
if [ -z "$START_IP" ] || [ -z "$SUBNET_MASK" ]; then
  echo "Error parsing start_ip/cidr: $START_IP_CIDR. Format must be X.X.X.X/XX"
  exit 1
fi

###############################################################################
# 2. IP CONVERSION UTILITIES
###############################################################################

# Convert dotted IP string to integer
ip_to_int() {
  local a b c d
  IFS=. read -r a b c d <<< "$1"
  echo "$((a * 256 ** 3 + b * 256 ** 2 + c * 256 + d))"
}

# Convert integer to dotted IP string
int_to_ip() {
  local ip
  ip=$(printf "%d.%d.%d.%d" \
      "$(( ($1 >> 24) & 255 ))" \
      "$(( ($1 >> 16) & 255 ))" \
      "$(( ($1 >> 8)  & 255 ))" \
      "$((  $1        & 255 ))")
  echo "$ip"
}

START_IP_INT=$(ip_to_int "$START_IP")

###############################################################################
# 3. BULK UPDATE LOOP
###############################################################################

echo "=== Starting IP update for $NUM_CTS container(s) ==="
echo " - Starting container ID: $START_CT_ID"
echo " - Starting IP: $START_IP/$SUBNET_MASK"
[ -n "$GATEWAY" ] && echo " - Gateway: $GATEWAY"

for (( i=0; i<NUM_CTS; i++ )); do
  CURRENT_CT_ID=$((START_CT_ID + i))
  CURRENT_IP_INT=$((START_IP_INT + i))
  NEW_IP=$(int_to_ip "$CURRENT_IP_INT")

  # Check if container exists
  if pct config "$CURRENT_CT_ID" &>/dev/null; then
    echo "Updating IP for container $CURRENT_CT_ID to $NEW_IP/$SUBNET_MASK on $BRIDGE..."

    # Apply the new network settings
    if [ -z "$GATEWAY" ]; then
      # No gateway specified
      pct set "$CURRENT_CT_ID" -net0 name=eth0,bridge="$BRIDGE",ip="$NEW_IP/$SUBNET_MASK"
    else
      pct set "$CURRENT_CT_ID" -net0 name=eth0,bridge="$BRIDGE",ip="$NEW_IP/$SUBNET_MASK",gw="$GATEWAY"
    fi

    if [ $? -eq 0 ]; then
      echo " - Successfully updated container $CURRENT_CT_ID."
    else
      echo " - Failed to update container $CURRENT_CT_ID (check errors above)."
    fi
  else
    echo " - Container $CURRENT_CT_ID does not exist. Skipping."
  fi
done

echo "=== Bulk IP change process complete! ==="
echo "If the containers are running, you may need to restart them or reapply networking for the changes to take effect."
