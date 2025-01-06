#!/bin/bash
#
# OnlineMemoryTest.sh
#
# A script to perform an in-memory RAM test on a running Proxmox server without fully shutting down.
# Uses the 'memtester' utility to allocate and test a portion of system memory in gigabytes.
#
# Usage:
#   ./OnlineMemoryTest.sh <size-in-GB>
#
# Examples:
#   ./OnlineMemoryTest.sh 1
#       This command tests 1GB (1024MB) of RAM in a running system.
#
#   ./OnlineMemoryTest.sh 2
#       This command tests 2GB (2048MB) of RAM in a running system.
#
# Note:
#   - Running this script may temporarily reduce available memory for other processes.
#   - For best results, stop or pause non-critical workloads before testing.
#   - This script MUST be run as root to install or remove packages if they are missing or no longer needed.

set -e

# --- Preliminary Checks -----------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root (sudo)."
  exit 1
fi

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <size-in-GB>"
  exit 1
fi

TEST_SIZE_GB="$1"

# Validate that the argument is a positive integer
re='^[0-9]+$'
if ! [[ "$TEST_SIZE_GB" =~ $re ]]; then
  echo "Error: <size-in-GB> must be a positive integer."
  exit 2
fi

# Convert GB to MB
TEST_SIZE_MB=$(( TEST_SIZE_GB * 1024 ))

# --- Check for memtester and Install if Necessary ---------------------------
if ! command -v memtester &>/dev/null; then
  echo "Installing 'memtester' package..."
  if ! apt-get update -y; then
    echo "Error: Failed to update package lists."
    exit 3
  fi

  if ! apt-get install -y memtester; then
    echo "Error: Failed to install memtester."
    exit 3
  fi
fi

# --- Main Script Logic ------------------------------------------------------
echo "Starting in-memory test for ${TEST_SIZE_MB}MB (${TEST_SIZE_GB}GB)..."
memtester "${TEST_SIZE_MB}M" 1
echo "Memory test completed. Check output above for any errors or failures."

# --- Optional Cleanup -------------------------------------------------------
read -r -p "Do you want to remove 'memtester' now? (y/N): " REMOVE_MEMTESTER
case "$REMOVE_MEMTESTER" in
  [yY][eE][sS]|[yY])
    echo "Removing 'memtester' package..."
    if ! apt-get remove -y memtester; then
      echo "Error: Failed to remove memtester."
      exit 4
    fi
    echo "'memtester' has been removed."
    ;;
  *)
    echo "Keeping 'memtester' installed."
    ;;
esac

exit 0
