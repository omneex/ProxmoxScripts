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
#

source "$UTILITIES"

check_root
check_proxmox

###############################################################################
# Validate arguments
###############################################################################
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /dev/sdX"
  exit 1
fi

DISK="$1"

if [[ ! "$DISK" =~ ^/dev/ ]]; then
  echo "Error: Invalid disk specified. Please provide a valid /dev/sdX path."
  exit 2
fi

###############################################################################
# Check and/or install required commands
###############################################################################
install_or_prompt "parted"
install_or_prompt "util-linux"  # Provides wipefs
install_or_prompt "coreutils"

###############################################################################
# Confirmation
###############################################################################
echo "WARNING: This script will wipe and remove partitions/signatures on \"$DISK\"."
echo "This operation is destructive and cannot be undone."
read -r -p "Are you sure you want to continue? (y/N): " confirmWipe
if [[ "$confirmWipe" != "y" && "$confirmWipe" != "Y" ]]; then
  echo "Aborting. No changes were made."
  exit 0
fi

###############################################################################
# Remove Partition Tables and Ceph Signatures
###############################################################################
echo "Removing partition tables and file system signatures on \"$DISK\"..."
wipefs --all --force "$DISK"

echo "Re-initializing partition label on \"$DISK\"..."
parted -s "$DISK" mklabel gpt

###############################################################################
# Optional Zero Fill
###############################################################################
read -r -p "Would you like to overwrite the disk with zeroes? (y/N): " overwrite
if [[ "$overwrite" == "y" || "$overwrite" == "Y" ]]; then
  install_or_prompt "coreutils"
  echo "Overwriting \"$DISK\" with zeroes. This may take a while..."
  dd if=/dev/zero of="$DISK" bs=1M status=progress || {
    echo "Error: Failed to overwrite disk with zeroes."
    exit 5
  }
  sync
  echo "Zero-fill complete."
else
  echo "Skipping zero-fill as per user choice."
fi

###############################################################################
# Prompt to keep newly installed packages
###############################################################################
prompt_keep_installed_packages
