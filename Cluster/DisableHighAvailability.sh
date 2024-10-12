#!/bin/bash

# This script disables high availability (HA) for the Proxmox VE cluster if only one or two nodes are available in the cluster.
#
# Usage:
# ./DisableHAIfFewNodes.sh

# Get the number of nodes in the cluster
NODE_COUNT=$(pvecm nodes | awk 'NR>1' | wc -l)

# Check if the number of nodes is one or two
if [ "$NODE_COUNT" -le 2 ]; then
    echo "Only $NODE_COUNT node(s) available in the cluster. Disabling high availability..."
    # Disable HA for the cluster
    for HA_RESOURCE in $(pvesh get /cluster/ha/resources --output-format json | jq -r '.[].sid'); do
        pvesh delete /cluster/ha/resources/$HA_RESOURCE
        echo " - Disabled HA for resource: $HA_RESOURCE"
    done
    echo "High availability disabled for the cluster."
else
    echo "Cluster has $NODE_COUNT nodes. High availability will remain enabled."
fi

echo "HA disable check completed!"