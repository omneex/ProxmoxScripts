#!/bin/bash
#
# CreateHAGroup.sh
#
# This script creates a High Availability (HA) group in the Proxmox VE cluster
# and adds the specified VMs to the group.
#
# Usage:
#   ./CreateHAGroup.sh <group_name> <vm_id_1> [<vm_id_2> ... <vm_id_n>]
#
# Example:
#   ./CreateHAGroup.sh myHAGroup 100 101 102
#
# Notes:
#   - You must be root or run via sudo.
#   - This script assumes you have a working Proxmox VE cluster.
#   - The script relies on utility functions that must be sourced elsewhere.
#

source $UTILITIES

###############################################################################
# MAIN
###############################################################################

# Basic checks
check_root            # Ensure script is run as root
check_proxmox         # Ensure we are on a Proxmox node
check_cluster_membership

# Argument parsing
if [[ "$#" -lt 2 ]]; then
    echo "Usage: ${0} <group_name> <vm_id_1> [<vm_id_2> ... <vm_id_n>]"
    exit 1
fi

local GROUP_NAME="$1"
shift
local -a VM_IDS=("$@")

# Create the HA group
echo "Creating HA group: '${GROUP_NAME}'..."
if ! pvesh create /cluster/ha/groups --group "${GROUP_NAME}" --comment "HA group created by script"; then
    echo "Error: Failed to create HA group: '${GROUP_NAME}'"
    exit 1
fi
echo "HA group '${GROUP_NAME}' created successfully."

# Add the specified VMs to the HA group
for vmId in "${VM_IDS[@]}"; do
    echo "Adding VM ID: '${vmId}' to HA group: '${GROUP_NAME}'..."
    if pvesh create /cluster/ha/resources --sid "vm:${vmId}" --group "${GROUP_NAME}"; then
        echo " - VM ID: '${vmId}' added to HA group: '${GROUP_NAME}'."
    else
        echo " - Failed to add VM ID: '${vmId}' to HA group: '${GROUP_NAME}'."
    fi
done

echo "=== HA group setup process completed! ==="

