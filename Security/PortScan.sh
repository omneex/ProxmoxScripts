#!/bin/bash
#
# PortScan.sh
#
# A script to scan one or multiple Proxmox hosts (or all in a cluster) to identify
# which TCP ports are open. The script attempts to install nmap if not present, then
# after the scan, it asks if nmap should be kept or removed.
#
# Usage:
#   ./PortScan.sh <target-host> [<additional-hosts> ...]
#   ./PortScan.sh all
#
# Examples:
#   ./PortScan.sh 192.168.1.50
#       Scans a single host at 192.168.1.50 for open TCP ports.
#
#   ./PortScan.sh 192.168.1.50 192.168.1.51 192.168.1.52
#       Scans multiple specified hosts for open TCP ports.
#
#   ./PortScan.sh all
#       Discovers all cluster nodes from the Proxmox cluster configuration,
#       then runs the open port scan on each node.
#
# Note: Use responsibly and only with explicit permission. Unauthorized port
# scanning may be illegal.
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
      # Adjust for your package manager if needed
      apt-get update && apt-get install -y nmap
      NMAP_INSTALLED_BY_SCRIPT=1
    else
      echo "nmap is required for this script to run a port scan. Exiting."
      exit 2
    fi
  fi
}

function ask_keep_or_remove_nmap() {
  # If we installed nmap, ask if user wants to keep it or remove it
  if [[ $NMAP_INSTALLED_BY_SCRIPT -eq 1 ]]; then
    echo "[*] Port scanning finished."
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

# 4. Port Scanning Section
# We'll use nmap to scan all TCP ports (-p-) and show only open ports (--open).
# We skip DNS resolution with -n for speed and anonymity if needed.
for HOST in "${TARGETS[@]}"; do
  echo "======================================================================="
  echo "[*] Scanning open TCP ports for host: $HOST"
  echo "======================================================================="
  nmap -p- --open -n "$HOST"
  echo "======================================================================="
  echo "[*] Finished scanning $HOST"
  echo "======================================================================="
  echo
done

# 5. Ask user if they want to remove nmap (if we installed it)
ask_keep_or_remove_nmap

exit 0
