#!/bin/bash
#
# This script sets the DNS servers and search domain for all nodes in the Proxmox VE cluster,
# using each node's IP from the 'Membership information' section of 'pvecm status' (instead
# of DNS names).
#
# Usage:
#   ./BulkSetDNS.sh <dns_server_1> <dns_server_2> <search_domain>
#
# Example:
#   ./BulkSetDNS.sh 8.8.8.8 8.8.4.4 mydomain.local
#
# Explanation:
#   - We parse 'pvecm status' to find membership lines (lines starting with "0x"),
#     then skip any line that contains "(local)".
#   - The IP is taken from the 3rd AWK field in those lines.
#   - Then we SSH into each remote node via that IP and write /etc/resolv.conf.
#   - Finally, we configure DNS on the local node as well.
#
# Prerequisites:
#   - Must be run as root (sudo) on an existing Proxmox cluster node.
#   - SSH access (root) must be allowed on each remote node (i.e. you can SSH as root).
#
# Changes:
#   - V1.0: 
#       - Now uses IP address to connect for setting DNS.

set -e

# --- Validate usage ---------------------------------------------------------
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <dns_server_1> <dns_server_2> <search_domain>"
  exit 1
fi

DNS1=$1
DNS2=$2
SEARCH_DOMAIN=$3

# --- Parse node IPs from 'pvecm status' membership lines --------------------
# We look for lines starting with "0x" (i.e., the node ID),
# skip lines containing "(local)", and print the third AWK field (the IP).
REMOTE_NODES=$(pvecm status | awk '/^0x/ && !/\(local\)/ {print $3}')

# --- Update DNS on each remote node -----------------------------------------
for NODE_IP in $REMOTE_NODES; do
  echo "-----------------------------------------------------------"
  echo "Setting DNS on remote node IP: $NODE_IP"
  echo "  DNS1=$DNS1, DNS2=$DNS2, SEARCH_DOMAIN=$SEARCH_DOMAIN"
  
  # SSH into the node and overwrite /etc/resolv.conf
  ssh -o StrictHostKeyChecking=no root@"$NODE_IP" \
    "echo -e 'search $SEARCH_DOMAIN\nnameserver $DNS1\nnameserver $DNS2' > /etc/resolv.conf"
  
  if [ $? -eq 0 ]; then
      echo "  - DNS configured successfully on $NODE_IP"
  else
      echo "  - Failed to configure DNS on $NODE_IP"
  fi
  echo
done

# --- Update DNS on the local node ------------------------------------------
echo "-----------------------------------------------------------"
echo "Setting DNS on the local node:"
echo "  DNS1=$DNS1, DNS2=$DNS2, SEARCH_DOMAIN=$SEARCH_DOMAIN"
echo -e "search $SEARCH_DOMAIN\nnameserver $DNS1\nnameserver $DNS2" > /etc/resolv.conf
if [ $? -eq 0 ]; then
  echo "  - DNS configured successfully on local node"
else
  echo "  - Failed to configure DNS on local node"
fi

echo
echo "=== DNS and search domain setup completed for all nodes! ==="
