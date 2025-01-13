#!/bin/bash
#
# TestUtilityFunctions.sh
#
# A sample script to demonstrate usage of the various functions from Utilities.sh,
# including testing the spinner functionality. It sources Utilities.sh, tests each
# utility function, and prints results.
#
# Usage:
#   1. Place this script in the same directory as Utilities.sh (or adjust the path).
#   2. Run it as root on a Proxmox node:
#       sudo ./TestUtilityFunctions.sh
#
# Note:
#   - This script may install packages if they are not already present (e.g., 'zip', 'jq').
#   - At the end, it will prompt whether to keep or remove any packages installed
#     during this session.

# Source the utility functions
source "./Utilities.sh"

###############################################################################
# 0. Basic checks
###############################################################################
check_root
check_proxmox

# We'll need 'jq' for many cluster queries
install_or_prompt "jq"

# We'll also test installing 'zip' as an example
install_or_prompt "zip"

###############################################################################
# 1. Spinner Test
###############################################################################
echo
echo "=== Testing the spinner (rainbow spinner) ==="
info "Spinner test... this will run for ~5 seconds."
sleep 5
ok "Spinner test complete!"

echo
info "Demonstrating spinner followed by an error message in ~3 seconds."
sleep 3
err "Simulated error message (no real error, just demonstrating)."

###############################################################################
# 2. Cluster / Node Utilities
###############################################################################
echo
echo "=== Testing get_remote_node_ips ==="
readarray -t REMOTE_NODES < <( get_remote_node_ips )
if [[ ${#REMOTE_NODES[@]} -gt 0 ]]; then
  echo "Remote node IPs: ${REMOTE_NODES[@]}"
else
  echo "No remote nodes found, or this node is not in a cluster."
fi

echo
echo "=== Testing check_cluster_membership ==="
check_cluster_membership
echo "Success: Node is in a cluster."

echo
echo "=== Testing get_number_of_cluster_nodes ==="
num_nodes=$(get_number_of_cluster_nodes)
echo "Number of cluster nodes: $num_nodes"

###############################################################################
# 3. IP Conversion Tests
###############################################################################
echo
echo "=== Testing IP conversion functions (ip_to_int and int_to_ip) ==="
EXAMPLE_IP="172.20.83.21"
IP_INT=$(ip_to_int "$EXAMPLE_IP")
echo "Converted $EXAMPLE_IP to integer: $IP_INT"

BACK_TO_IP=$(int_to_ip "$IP_INT")
echo "Converted integer $IP_INT back to IP: $BACK_TO_IP"

###############################################################################
# 4. Node name <-> IP Mapping
###############################################################################
echo
echo "=== Testing get_ip_from_name and get_name_from_ip ==="
LOCAL_NODE_NAME="$(hostname -s)"
echo "Local node short name: $LOCAL_NODE_NAME"

LOCAL_NODE_IP="$(get_ip_from_name "$LOCAL_NODE_NAME" 2>/dev/null)" || true

if [[ -n "$LOCAL_NODE_IP" ]]; then
  echo "get_ip_from_name returned IP: $LOCAL_NODE_IP"

  NAME_FROM_IP="$(get_name_from_ip "$LOCAL_NODE_IP" 2>/dev/null)" || true
  echo "get_name_from_ip($LOCAL_NODE_IP) => $NAME_FROM_IP"
else
  echo "Warning: Could not map name '$LOCAL_NODE_NAME' to an IP. Possibly not in cluster maps?"
fi

###############################################################################
# 5. Container Queries
###############################################################################
echo
echo "=== Testing get_cluster_lxc ==="
readarray -t CLUSTER_LXC < <( get_cluster_lxc )
if [[ ${#CLUSTER_LXC[@]} -gt 0 ]]; then
  echo "Cluster LXC VMIDs: ${CLUSTER_LXC[@]}"
else
  echo "No LXC containers found in the cluster."
fi

echo
echo "=== Testing get_server_lxc (on 'local' node) ==="
readarray -t LOCAL_LXC < <( get_server_lxc "local" )
if [[ ${#LOCAL_LXC[@]} -gt 0 ]]; then
  echo "Local LXC VMIDs: ${LOCAL_LXC[@]}"
else
  echo "No LXC containers found on local node."
fi

###############################################################################
# 6. VM Queries
###############################################################################
echo
echo "=== Testing get_cluster_vms ==="
readarray -t CLUSTER_VMS < <( get_cluster_vms )
if [[ ${#CLUSTER_VMS[@]} -gt 0 ]]; then
  echo "Cluster QEMU VMIDs: ${CLUSTER_VMS[@]}"
else
  echo "No QEMU VMs found in the cluster."
fi

echo
echo "=== Testing get_server_vms (on 'local' node) ==="
readarray -t LOCAL_VMS < <( get_server_vms "local" )
if [[ ${#LOCAL_VMS[@]} -gt 0 ]]; then
  echo "Local QEMU VMIDs: ${LOCAL_VMS[@]}"
else
  echo "No QEMU VMs found on local node."
fi

###############################################################################
# 7. Prompt to Keep or Remove Installed Packages
###############################################################################
echo
echo "=== Testing prompt_keep_installed_packages ==="
prompt_keep_installed_packages

echo
echo "=== Test Script Complete ==="
