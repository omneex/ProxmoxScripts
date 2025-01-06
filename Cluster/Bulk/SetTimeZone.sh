#!/bin/bash
#
# This script sets the time server for all nodes in the Proxmox VE cluster.
# The default timezone is set to America/New_York.
#
# Usage:
# ./SetTimeServer.sh <timezone>

# Assign the timezone, default to America/New_York if not provided
TIMEZONE=${1:-America/New_York}

# Loop through all nodes in the cluster
NODES=$(pvecm nodes | awk 'NR>1 {print $2}')
for NODE in $NODES; do
    echo "Setting timezone to $TIMEZONE on node: $NODE"
    ssh root@$NODE "timedatectl set-timezone $TIMEZONE"
    if [ $? -eq 0 ]; then
        echo " - Timezone set successfully on node: $NODE"
    else
        echo " - Failed to set timezone on node: $NODE"
    fi
done

# Set the timezone on the local node
echo "Setting timezone to $TIMEZONE on local node"
timedatectl set-timezone $TIMEZONE
if [ $? -eq 0 ]; then
    echo " - Timezone set successfully on local node"
else
    echo " - Failed to set timezone on local node"
fi

echo "Timezone setup completed for all nodes!"