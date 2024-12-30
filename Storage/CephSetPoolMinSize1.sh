#!/bin/bash
#
# This script is designed to configure the 'min_size' parameter of a specified Ceph storage pool.
# The 'min_size' parameter determines the minimum number of replicas that must be available for the 
# cluster to allow read and write operations. Setting this to '1' allows the cluster to operate in 
# degraded mode. This script is useful for administrators needing to ensure continued data availability
# under specific circumstances where reduced redundancy is temporarily acceptable.
#
# Usage:
# ./CephSetPoolMinSize1.sh <pool_name>
#   pool_name - The name of the Ceph storage pool to configure.
# Example:
#   ./CephSetPoolMinSize1.sh mypool

# Check if the pool name is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <pool_name>"
    exit 1
fi

POOL_NAME=$1

# Command to set the min_size of the pool
echo "Setting min_size of pool '$POOL_NAME' to 1..."
ceph osd pool set "$POOL_NAME" min_size 1 --yes-i-really-mean-it

if [ $? -eq 0 ]; then
    echo "min_size has been set to 1 for pool '$POOL_NAME'."
else
    echo "Failed to set min_size for pool '$POOL_NAME'. Please check the pool name and your permissions."
fi
