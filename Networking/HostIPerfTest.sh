#!/bin/bash
#
# HostIPerfTest.sh
#
# Automates an Iperf throughput test between two specified hosts, allowing you
# to define which is the server and which is the client by hostname.
# Optionally installs and uninstalls the latest iperf3 package.
#
# Usage:
#   ./HostIPerfTest.sh <server_host> <client_host> <port>
#
# Example:
#   ./HostIPerfTest.sh 192.168.1.10 192.168.1.11 5001
#
# This script will:
#   1. Prompt the user to install the latest iperf3 if not already installed.
#   2. Start an iperf3 server on the specified server host using SSH.
#   3. Run the iperf3 client on the specified client host to display throughput results.
#   4. Kill the iperf3 server process automatically upon completion.
#   5. Prompt the user if they would like to uninstall iperf3 afterward.
#

# --- Exit on any non-zero command ---------------------------------------------
set -e

# --- Preliminary Checks -------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root (sudo)."
  exit 1
fi

if ! command -v ssh &>/dev/null; then
  echo "Error: 'ssh' command not found, please install or check your PATH."
  exit 2
fi

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <server_host> <client_host> <port>"
  exit 3
fi

# --- Argument Parsing ---------------------------------------------------------
SERVER_HOST="$1"
CLIENT_HOST="$2"
PORT="$3"

# --- Iperf Installation Check & Prompt ---------------------------------------
if ! command -v iperf3 &>/dev/null; then
  echo "iperf3 is not currently installed on this machine."
  read -r -p "Would you like to install the latest iperf3 now? [y/N] " INSTALL_CHOICE
  if [[ "$INSTALL_CHOICE" =~ ^[Yy]$ ]]; then
    apt-get update
    apt-get install -y iperf3
    echo "iperf3 installed successfully on the local machine."
  else
    echo "Cannot proceed without iperf3 installed locally. Exiting."
    exit 4
  fi
else
  read -r -p "iperf3 is already installed on this machine. Reinstall latest iperf3? [y/N] " REINSTALL_CHOICE
  if [[ "$REINSTALL_CHOICE" =~ ^[Yy]$ ]]; then
    apt-get update
    apt-get install -y --only-upgrade iperf3
    echo "iperf3 upgraded (if a newer version was available)."
  fi
fi

# --- Start Iperf Server on Server Host ----------------------------------------
echo "Starting iperf3 server on '$SERVER_HOST'..."
ssh "root@$SERVER_HOST" "pkill -f 'iperf3 -s' || true"
ssh "root@$SERVER_HOST" "iperf3 -s -p \"$PORT\" &" &

# Give some time for the server to start
echo "Waiting 5 seconds for the iperf3 server to be ready..."
sleep 5

# --- Run Iperf Client on Client Host ------------------------------------------
echo "Running iperf3 client on '$CLIENT_HOST' connecting to '$SERVER_HOST'..."
ssh "root@$CLIENT_HOST" "iperf3 -c \"$SERVER_HOST\" -p \"$PORT\" -t 10"

# --- Kill the Iperf Server ----------------------------------------------------
echo "Stopping iperf3 server on '$SERVER_HOST'..."
ssh "root@$SERVER_HOST" "pkill -f 'iperf3 -s'"

echo "Iperf test completed successfully."

# --- Prompt for Uninstall -----------------------------------------------------
read -r -p "Would you like to uninstall iperf3 locally? [y/N] " UNINSTALL_CHOICE
if [[ "$UNINSTALL_CHOICE" =~ ^[Yy]$ ]]; then
  apt-get remove -y iperf3
  echo "iperf3 uninstalled successfully."
fi
