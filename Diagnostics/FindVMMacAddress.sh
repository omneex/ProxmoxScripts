#!/bin/bash

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