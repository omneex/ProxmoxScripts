#!/bin/bash
#
# SetTimeServer.sh
#
# A script to set the timezone across all nodes in a Proxmox VE cluster.
# Defaults to "America/New_York" if no argument is provided.
#
# Usage:
#   ./SetTimeServer.sh <timezone>
#
# Examples:
#   ./SetTimeServer.sh
#   ./SetTimeServer.sh "Europe/Berlin"
#
# This script will:
#   1. Check if running as root (check_root).
#   2. Check if on a valid Proxmox node (check_proxmox).
#   3. Verify the node is part of a cluster (check_cluster_membership).
#   4. Gather remote node IPs from get_remote_node_ips.
#   5. Set the specified timezone on each remote node and then on the local node.
#

source "$UTILITIES"

###############################################################################
# Pre-flight checks
###############################################################################
check_root
check_proxmox
check_cluster_membership

###############################################################################
# Main
###############################################################################
TIMEZONE="${1:-America/New_York}"
echo "Selected timezone: \"${TIMEZONE}\""

# Gather IP addresses of all remote nodes
readarray -t REMOTE_NODES < <( get_remote_node_ips )

# Set timezone on each remote node
for nodeIp in "${REMOTE_NODES[@]}"; do
    echo "Setting timezone to \"${TIMEZONE}\" on node: \"${nodeIp}\""
    if ssh "root@${nodeIp}" "timedatectl set-timezone \"${TIMEZONE}\""; then
        echo " - Timezone set successfully on node: \"${nodeIp}\""
    else
        echo " - Failed to set timezone on node: \"${nodeIp}\""
    fi
done

# Finally, set the timezone on the local node
echo "Setting timezone to \"${TIMEZONE}\" on local node..."
if timedatectl set-timezone "${TIMEZONE}"; then
    echo " - Timezone set successfully on local node"
else
    echo " - Failed to set timezone on local node"
fi

echo "Timezone setup completed for all nodes!"

###############################################################################
# Testing status
###############################################################################
# Tested single-node
# Tested multi-node
