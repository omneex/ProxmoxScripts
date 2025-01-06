#!/bin/bash
#
# PenetrationTest.sh
#
# A script to conduct a basic vulnerability assessment (pentest) on one or multiple Proxmox hosts.
# This version will attempt to install nmap if it is not present on the system, and then
# ask if the user wants to keep or remove nmap when the script finishes.
#
# Usage:
#   ./PenetrationTest.sh <target-host> [<additional-hosts> ...]
#   ./PenetrationTest.sh all
#
# Examples:
#   ./PenetrationTest.sh 192.168.1.50
#       Conducts a pentest on a single host at 192.168.1.50.
#
#   ./PenetrationTest.sh 192.168.1.50 192.168.1.51 192.168.1.52
#       Conducts a pentest on multiple specified hosts.
#
#   ./PenetrationTest.sh all
#       Discovers all cluster nodes from the Proxmox cluster configuration,
#       then runs nmap-based checks on each node.
#
# Note: This script performs a non-exhaustive scan and should be used only with
# explicit permission. Pentesting without permission is illegal.
#
# ------------------------------------------------------------------------------

set -e  # Exit immediately on any non-zero command return

# --- Preliminary Checks -------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root (sudo)."
  exit 1
fi

if ! command -v pvecm &>/dev/null; then
  echo "Warning: 'pvecm' command not found. Are you sure this is a Proxmox node?"
  echo "The script can still run but won't discover cluster hosts automatically."
fi

# --- Global Variables ---------------------------------------------------------
NMAP_INSTALLED_BY_SCRIPT=0  # Flag to track if this script installed nmap

# --- Helper Functions ---------------------------------------------------------

function usage() {
  echo "Usage: $0 <target-host> [<additional-hosts> ...]"
  echo "       $0 all"
  echo
  echo "Examples:"
  echo "  $0 192.168.1.50"
  echo "  $0 192.168.1.50 192.168.1.51 192.168.1.52"
  echo "  $0 all"
  exit 1
}

function discover_cluster_hosts() {
  # This function attempts to discover all hosts in a Proxmox cluster using pvecm.
  # We parse the output of 'pvecm status' for node IP addresses.

  local hosts_list
  hosts_list=$(pvecm status 2>/dev/null | grep -E "Address:" | awk '{print $2}' || true)
  echo "$hosts_list"
}

function install_nmap_if_missing() {
  # Check if nmap is installed
  if ! command -v nmap &>/dev/null; then
    # Ask user if they'd like to install it
    echo "It appears 'nmap' is not installed on this system."
    read -r -p "Would you like to install nmap now? [y/N] " RESP
    if [[ "$RESP" =~ ^[Yy]$ ]]; then
      echo "[*] Installing nmap..."
      # Adjust for your package manager if needed (apt-get, yum, etc.)
      apt-get update && apt-get install -y nmap
      NMAP_INSTALLED_BY_SCRIPT=1
    else
      echo "nmap is required for this script to run a vulnerability scan. Exiting."
      exit 2
    fi
  fi
}

function ask_keep_or_remove_nmap() {
  # If we installed nmap, ask if user wants to keep it or remove it
  if [[ $NMAP_INSTALLED_BY_SCRIPT -eq 1 ]]; then
    echo "[*] Pentest finished."
    read -r -p "Would you like to remove nmap from the system? [y/N] " REMOVE_RESP
    if [[ "$REMOVE_RESP" =~ ^[Yy]$ ]]; then
      echo "[*] Removing nmap..."
      apt-get remove -y nmap
    else
      echo "[*] Keeping nmap installed."
    fi
  fi
}

# --- Main Script Logic --------------------------------------------------------

# 1. Check for arguments
if [[ $# -lt 1 ]]; then
  usage
fi

# 2. Ensure nmap is installed (or install it)
install_nmap_if_missing

# 3. Build a list of target hosts
if [[ "$1" == "all" ]]; then
  echo "[*] Attempting to discover all hosts in the Proxmox cluster..."
  DISCOVERED_HOSTS=$(discover_cluster_hosts)

  if [[ -z "$DISCOVERED_HOSTS" ]]; then
    echo "Error: No hosts discovered via pvecm. Are you sure this node is part of a cluster?"
    exit 3
  fi

  echo "[*] Hosts discovered:"
  echo "$DISCOVERED_HOSTS"
  TARGETS=($DISCOVERED_HOSTS)
else
  TARGETS=("$@")
fi

# 4. Pentest Section: run a basic vulnerability scan on each target
for HOST in "${TARGETS[@]}"; do
  echo "======================================================================="
  echo "[*] Starting vulnerability scan for host: $HOST"
  echo "======================================================================="

  # Basic nmap command with vulnerability scripts
  nmap -sV --script vuln "$HOST"

  echo "======================================================================="
  echo "[*] Finished scanning $HOST"
  echo "======================================================================="
  echo
done

# 5. Ask user if they want to remove nmap (if we installed it)
ask_keep_or_remove_nmap

exit 0
