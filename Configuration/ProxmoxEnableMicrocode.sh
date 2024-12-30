#!/bin/bash
#
# This script enables microcode updates for all nodes in a Proxmox VE cluster.
#
# Usage:
# ./ProxmoxEnableMicrocode.sh

# Function to enable microcode updates
enable_microcode() {
    echo "Enabling microcode updates on node: $(hostname)"
    apt-get update && apt-get install -y intel-microcode amd64-microcode
    echo " - Microcode updates enabled."
}

# Loop through all nodes in the cluster
for NODE in $(pvecm nodes | awk 'NR>1 {print $2}'); do
    echo "Connecting to node: $NODE"
    ssh root@$NODE "$(declare -f enable_microcode); enable_microcode"
    echo " - Microcode update completed for node: $NODE"
done

# Update the local node
enable_microcode

echo "Microcode updates enabled for all nodes!"