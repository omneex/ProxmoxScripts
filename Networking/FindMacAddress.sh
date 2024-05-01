#!/bin/bash

# This script retrieves the network configuration details for all virtual machines (VMs) across all nodes in a Proxmox cluster.
# It outputs the MAC addresses associated with each VM, helping in network configuration audits or inventory management.
# The script utilizes the Proxmox VE command-line tool `pvesh` to fetch information in JSON format and parses it using `jq`.
#
# Usage:
# Simply run this script on a Proxmox cluster host that has permissions to access the Proxmox VE API:
# ./FindMacAddress.sh

# Get a list of all nodes
nodes=$(pvesh get /nodes --output-format=json | jq -r '.[] | .node')

# Iterate over each node
for node in $nodes; do
    echo "Checking node: $node"
    
    # Get a list of all VMIDs on the node
    vmids=$(pvesh get /nodes/$node/qemu --output-format=json | jq -r '.[] | .vmid')
    
    # Iterate over each VMID
    for vmid in $vmids; do
        echo "VMID: $vmid on Node: $node"
        
        # Get network configuration details for each VM
        pvesh get /nodes/$node/qemu/$vmid/config | grep -i 'net' | grep -i 'macaddr'
    done
done
