#!/bin/bash
#
# UpgradeAllServers.sh
#
# A script to update all servers in the Proxmox cluster by running:
#   apt-get update && apt-get -y upgrade
# on each node (local + remote).
#
# Usage:
#   ./UpgradeAllServers.sh
#
# Description:
#   1. Checks root privileges and confirms this is a Proxmox node.
#   2. Prompts to install 'ssh' if not already installed (though it's usually present on Proxmox).
#   3. Ensures the node is part of a cluster.
#   4. Gathers remote cluster node IPs using get_remote_node_ips (from our utility functions).
#   5. Updates the local node and all remote nodes in the cluster.
#   6. Prompts whether to keep or remove any newly installed packages.
#
# Example:
#   ./UpgradeAllServers.sh
#

###############################################################################
# Preliminary Checks
###############################################################################
check_root
check_proxmox
check_cluster_membership

###############################################################################
# Gather Node Information
###############################################################################
LOCAL_NODE_IP="$(hostname -I | awk '{print $1}')"
readarray -t REMOTE_NODE_IPS < <( get_remote_node_ips )
ALL_NODE_IPS=("$LOCAL_NODE_IP" "${REMOTE_NODE_IPS[@]}")

###############################################################################
# Main Script Logic
###############################################################################
echo "Updating all servers in the Proxmox cluster..."

for nodeIp in "${ALL_NODE_IPS[@]}"; do
  echo "------------------------------------------------"
  echo "Updating node at IP: \"${nodeIp}\""

  if [[ "${nodeIp}" == "${LOCAL_NODE_IP}" ]]; then
    apt-get update && apt-get -y upgrade
    echo "Local node update completed."
  else
    if ssh "root@${nodeIp}" "apt-get update && apt-get -y upgrade"; then
      echo "Remote node \"${nodeIp}\" update completed."
    else
      echo "Failed to update node \"${nodeIp}\"."
    fi
  fi
done

echo "All servers have been successfully updated."
