#!/bin/bash
#
# UplinkSpeedTest.sh
#
# A script to check internet speed on a Proxmox node (local),
# or sequentially across all nodes in the cluster, then report the results.
#
# Usage:
#   ./UplinkSpeedTest.sh [all|<node1> <node2> ...]
#
# Examples:
#   1) Run speed test on the local node:
#        ./UplinkSpeedTest.sh
#   2) Run speed test on all nodes in the cluster:
#        ./UplinkSpeedTest.sh all
#   3) Run speed test on specific remote nodes:
#        ./UplinkSpeedTest.sh proxmox-node1 proxmox-node2
#
# This script relies on:
#   - pvecm (Proxmox utility) to identify cluster nodes
#   - ssh access to each remote node (passwordless or otherwise)
#   - speedtest command (e.g., speedtest-cli or Speedtest by Ookla) installed on each node
#   - jq (optional) for nicer JSON output parsing if desired
#
# ------------------------------------------------------------------------------

set -e  # Exit immediately on any non-zero command return

# --- Functions -----------------------------------------------------------------

usage() {
  echo "Usage: $0 [all|<node1> <node2> ...]"
  echo ""
  echo "Examples:"
  echo "  $0               # Test speed locally only"
  echo "  $0 all           # Test speed on all nodes in the cluster"
  echo "  $0 node1 node2   # Test speed on node1 and node2"
  exit 1
}

check_requirements() {
  # Check if we're on Proxmox (pvecm)
  if ! command -v pvecm &>/dev/null; then
    echo "Error: 'pvecm' not found. Are you sure this is a Proxmox node?"
    exit 2
  fi

  # Check if speedtest is available
  if ! command -v speedtest &>/dev/null; then
    echo "Warning: 'speedtest' command not found on this node."
    echo "Please install speedtest-cli or the Speedtest by Ookla."
  fi
}

# Run speed test on a single node
# Parameters:
#   1 -> Node name or IP
run_speedtest_on_node() {
  local node="$1"
  # We'll attempt an SSH if the node is not the local host
  # to see if "node" equals the local node's name or IP
  local this_node
  this_node="$(hostname)"

  if [[ "$node" == "$this_node" ]]; then
    # Local node
    echo "Running speed test locally on node: $node"
    speedtest
  else
    # Remote node
    echo "Running speed test on remote node: $node"
    ssh "root@$node" "speedtest"
  fi
}

# Gather all nodes in the cluster via pvecm
get_all_cluster_nodes() {
  # pvecm nodes output example:
  # Membership information
  # ----------------------
  # Nodeid Votes Name
  # 1      1     pmx1 (local)
  # 2      1     pmx2
  #
  # We skip the first 3 lines, parse the 3rd column, ignoring potential "(local)" text
  pvecm nodes | tail -n +3 | awk '{print $3}' | sed 's/(local)//g'
}

# --- Main Script Logic ---------------------------------------------------------

main() {
  # Preliminary checks
  check_requirements

  # If no arguments were provided, run on local node
  if [[ $# -eq 0 ]]; then
    run_speedtest_on_node "$(hostname)"
    exit 0
  fi

  # If "all" was specified, gather all nodes and run
  if [[ "$1" == "all" ]]; then
    # Read each node from the cluster and run the speed test
    echo "Gathering cluster nodes..."
    while read -r node; do
      # Skip empty lines if any
      [[ -z "$node" ]] && continue
      run_speedtest_on_node "$node"
      echo "-----------------------------------------------------"
    done < <(get_all_cluster_nodes)
    exit 0
  fi

  # Otherwise, treat each argument as a node
  for node in "$@"; do
    run_speedtest_on_node "$node"
    echo "-----------------------------------------------------"
  done
}

# ------------------------------------------------------------------------------

# Parse arguments and run main
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  usage
else
  main "$@"
fi
