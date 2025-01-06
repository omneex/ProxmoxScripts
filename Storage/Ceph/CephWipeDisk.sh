#!/bin/bash
#
# CephWipeDisk.sh
#
# Securely erase a disk previously used by Ceph for removal or redeployment.
# This script will:
#   1. Prompt for confirmation to wipe the specified disk.
#   2. Remove any existing partition tables and Ceph signatures.
#   3. Optionally overwrite the disk with zeroes.
#
# Usage:
#   ./CephWipeDisk.sh /dev/sdX
#
# Example:
#   ./CephWipeDisk.sh /dev/sdb
#
# Notes:
# - This script must be run as root (sudo).
# - Make sure you specify the correct disk. This operation is destructive!

set -e

# --- Preliminary Checks -----------------------------------------------------

if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root (sudo)."
  exit 1
fi

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /dev/sdX"
  exit 1
fi

DISK="$1"

# Basic validation for disk path
if [[ ! "$DISK" =~ ^/dev/ ]]; then
  echo "Error: Invalid disk specified. Please provide a valid /dev/sdX path."
  exit 2
fi

# Check required commands
for cmd in wipefs parted; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: '$cmd' command not found. Please install it or ensure it's in PATH."
    exit 3
  fi
done

# --- Confirmation -----------------------------------------------------------

echo "WARNING: This script will wipe and remove partitions/signatures on $DISK."
echo "This operation is destructive and cannot be undone."
read -r -p "Are you sure you want to continue? (y/N): " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "Aborting. No changes were made."
  exit 0
fi

# --- Remove Partition Tables and Ceph Signatures ----------------------------

# Remove all partition table signatures
echo "Removing partition tables and file system signatures on $DISK..."
wipefs --all --force "$DISK"

# Re-initialize GPT label (or you may use msdos, depending on your preference)
echo "Re-initializing partition label on $DISK..."
parted -s "$DISK" mklabel gpt

# --- Optional Zero Fill -----------------------------------------------------

read -r -p "Would you like to overwrite the disk with zeroes? (y/N): " OVERWRITE
if [[ "$OVERWRITE" == "y" || "$OVERWRITE" == "Y" ]]; then
  if ! command -v dd &>/dev/null; then
    echo "Error: 'dd' command not found. Cannot perform zero-fill."
    exit 4
  fi
  echo "Overwriting $DISK with zeroes. This may take a while..."
  dd if=/dev/zero of="$DISK" bs=1M status=progress || {
    echo "Error: Failed to overwrite disk with zeroes."
    exit 5
  }
  sync
  echo "Zero-fill complete."
else
  echo "Skipping zero-fill as per user choice."
fi

# --- Completion -------------------------------------------------------------

echo "Disk $DISK has been wiped successfully."
exit 0
