#!/bin/bash

# This script sets the DNS servers and search domain for all nodes in the Proxmox VE cluster.
#
# Usage:
# ./SetDNS.sh <dns_server_1> <dns_server_2> <search_domain>

# Check if the required parameters are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <dns_server_1> <dns_server_2> <search_domain>"
    exit 1
fi

# Assign the DNS servers and search domain
DNS1=$1
DNS2=$2
SEARCH_DOMAIN=$3

# Loop through all nodes in the cluster
NODES=$(pvecm nodes | awk 'NR>1 {print $2}')
for NODE in $NODES; do
    echo "Setting DNS servers and search domain on node: $NODE to $DNS1, $DNS2, and $SEARCH_DOMAIN"
    ssh root@$NODE "echo -e 'search $SEARCH_DOMAIN\nnameserver $DNS1\nnameserver $DNS2' > /etc/resolv.conf"
    if [ $? -eq 0 ]; then
        echo " - DNS servers and search domain set successfully on node: $NODE"
    else
        echo " - Failed to set DNS servers and search domain on node: $NODE"
    fi
done

# Set the DNS servers and search domain on the local node
echo "Setting DNS servers and search domain on local node to $DNS1, $DNS2, and $SEARCH_DOMAIN"
echo -e "search $SEARCH_DOMAIN\nnameserver $DNS1\nnameserver $DNS2" > /etc/resolv.conf
if [ $? -eq 0 ]; then
    echo " - DNS servers and search domain set successfully on local node"
else
    echo " - Failed to set DNS servers and search domain on local node"
fi

echo "DNS and search domain setup completed for all nodes!"