#!/bin/bash

# This script is used to configure the 'size' parameter of a specified Ceph storage pool.
# The 'size' parameter defines the number of replicas Ceph maintains for objects in the pool,
# setting this to '1' configures the pool to not use any data replication. This configuration 
# might be useful for temporary or test environments where data durability is not a concern.
# The script checks for user input and applies the configuration if valid, otherwise it 
# provides usage instructions.
#
# Usage:
# ./CephSetPoolSize1.sh <pool_name>
#   pool_name - The name of the Ceph storage pool to configure.
# Example:
#   ./CephSetPoolSize1.sh testpool

# Check if the pool name is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <pool_name>"
    exit 1
fi

POOL_NAME=$1

# Command to set the size of the pool
echo "Setting size of pool '$POOL_NAME' to 1..."
ceph osd pool set "$POOL_NAME" size 1 --yes-i-really-mean-it

if [ $? -eq 0 ]; then
    echo "size has been set to 1 for pool '$POOL_NAME'."
else
    echo "Failed to set size for pool '$POOL_NAME'. Please check the pool name and your permissions."
fi
