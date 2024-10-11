#!/bin/bash

# This script automates the process of cloning LXC containers within a Proxmox VE environment. It clones a source LXC container into
# a specified number of new containers, assigning them unique IDs, names based on a user-provided base name, and sets static IP addresses. 
# Adding cloned containers to a designated pool is optional. This script is particularly useful for quickly deploying multiple containers 
# based on a standardized configuration.
#
# Usage:
# ./CloneLXCs.sh <source_ct_id> <base_ct_name> <start_ct_id> <num_cts> <start_ip/cidr> <bridge> [gateway] [pool_name]
#
# Arguments:
#   source_ct_id - The ID of the LXC container that will be cloned.
#   base_ct_name - The base name for the new containers, which will be appended with a numerical index.
#   start_ct_id - The starting container ID for the first clone.
#   num_cts - The number of containers to clone.
#   start_ip/cidr - The new IP address and subnet mask of the container.
#   bridge - The bridge to be used for the network configuration.
#   gateway - The gateway for the IP configuration.
#   pool_name - Optional. The name of the pool to which the new containers will be added. If not provided, containers are not added to any pool.
#
# Example:
#   ./CloneLXCs.sh 110 Ubuntu-2C-20GB 400 30 192.168.1.50/24 vmbr0 192.168.1.1 PoolName
#   ./CloneLXCs.sh 110 Ubuntu-2C-20GB 400 30 192.168.1.50/24 vmbr0 # Without specifying a gateway or pool

# Check if the minimum required parameters are provided
if [ "$#" -lt 6 ]; then
    echo "Usage: $0 <source_ct_id> <base_ct_name> <start_ct_id> <num_cts> <start_ip/cidr> <bridge> [gateway] [pool_name]"
    exit 1
fi

# Assigning input arguments
SOURCE_CT_ID=$1
BASE_CT_NAME=$2
START_CT_ID=$3
NUM_CTS=$4
START_IP_CIDR=$5
BRIDGE=$6
GATEWAY=${7:-}  # Optional gateway, default to an empty string if not provided
POOL_NAME=${8:-}  # Optional pool name, default to an empty string if not provided

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
    ip=$(printf "%d.%d.%d.%d" "$((($1 >> 24) & 255))" "$((($1 >> 16) & 255))" "$((($1 >> 8) & 255))" "$(( $1 & 255 ))")
    echo "$ip"
}

# Get the starting IP as an integer
START_IP_INT=$(ip_to_int "$START_IP")

# Loop to create clones
for (( i=0; i<$NUM_CTS; i++ )); do
    TARGET_CT_ID=$((START_CT_ID + i))
    NAME_INDEX=$((i + 1))
    CT_NAME="${BASE_CT_NAME}${NAME_INDEX}"

    # Increment the IP address
    CURRENT_IP_INT=$((START_IP_INT + i))
    NEW_IP=$(int_to_ip "$CURRENT_IP_INT")

    # Clone the container and set the constructed name
    pct clone $SOURCE_CT_ID $TARGET_CT_ID --hostname $CT_NAME

    # Set the static IP, subnet mask, gateway, and bridge information
    pct set $TARGET_CT_ID -net0 name=eth0,bridge=${BRIDGE},ip=${NEW_IP}/${SUBNET_MASK},gw=${GATEWAY}

    # Check if a pool name was provided and add container to the pool if it was
    if [ -n "$POOL_NAME" ]; then
        pct set $TARGET_CT_ID --pool $POOL_NAME
    fi
done

echo "Cloning completed!"