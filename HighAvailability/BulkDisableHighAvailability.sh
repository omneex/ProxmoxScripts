#!/bin/bash
#
# DisableHAClusterWide.sh
#
# This script disables High Availability (HA) cluster-wide by:
#   1. Removing all HA resources found in the cluster (pvesh /cluster/ha/resources).
#   2. Stopping and disabling the HA services (pve-ha-crm and pve-ha-lrm) on every node.
#
# Usage:
#   ./DisableHAClusterWide.sh
#
# Example:
#   ./DisableHAClusterWide.sh
#
# Notes:
#   - This script expects passwordless SSH or valid root credentials for all nodes.
#   - Once completed, no node in the cluster will run HA services, and no HA resource definitions will remain.
#

###############################################################################
# MAIN
###############################################################################

echo "=== Disabling HA on the entire cluster ==="

# 1. Retrieve and remove all HA resources from the cluster.
echo "=== Retrieving all HA resources ==="
ALL_RESOURCES=$(pvesh get /cluster/ha/resources --output-format json | jq -r '.[].sid')

if [ -z "$ALL_RESOURCES" ]; then
  echo " - No HA resources found in the cluster."
else
  echo " - The following HA resources will be removed:"
  echo "$ALL_RESOURCES"
  echo
  
  for RES in $ALL_RESOURCES; do
    echo "Removing HA resource $RES ..."
    pvesh delete /cluster/ha/resources/"$RES"
    if [ $? -eq 0 ]; then
      echo " - Successfully removed HA resource: $RES"
    else
      echo " - Failed to remove HA resource: $RES"
    fi
    echo
  done
fi

# 2. Stop and disable HA services on every node in the cluster.
#    We get a list of node names from 'pvecm nodes', skipping the header line.
echo "=== Disabling HA services (CRM, LRM) on all nodes ==="
NODES=$(pvecm nodes | awk 'NR>1 {print $2}')

for NODE in $NODES; do
  echo " - Processing node: $NODE"
  
  # Stop services
  echo "   Stopping pve-ha-crm and pve-ha-lrm..."
  ssh root@"$NODE" "systemctl stop pve-ha-crm pve-ha-lrm"
  
  # Disable services
  echo "   Disabling pve-ha-crm and pve-ha-lrm on startup..."
  ssh root@"$NODE" "systemctl disable pve-ha-crm pve-ha-lrm"
  
  echo "   Done for node: $NODE"
  echo
done

echo "=== HA has been disabled on all nodes in the cluster. ==="
echo "No HA resources remain, and HA services are stopped & disabled cluster-wide."
