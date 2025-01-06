#!/bin/bash
#
# EnableIOMMU.sh
#
# A script to ensure VT-d/AMD-Vi (IOMMU) is enabled on a Proxmox host,
# preparing it for PCI passthrough. This script will:
#   1. Detect if CPU is Intel or AMD.
#   2. Update /etc/default/grub to include the appropriate IOMMU parameter
#      ("intel_iommu=on" or "amd_iommu=on").
#   3. Optionally blacklist GPU drivers (e.g., nouveau) if desired.
#   4. Update initramfs and Grub configuration.
#
# Usage:
#   ./EnableIOMMU.sh
#
# Example:
#   sudo ./EnableIOMMU.sh
#
# Notes:
#   - This script assumes a Debian-based (Proxmox) environment that uses Grub.
#   - If your system uses systemd-boot or another bootloader, you must adapt accordingly.
#   - You must reboot after running this script for changes to take effect.
#   - For GPU passthrough, you may also want to load VFIO modules (vfio, vfio_iommu_type1, vfio_pci)
#     at boot, and map specific PCI device IDs. Adjust /etc/modules or create a modprobe config as needed.
#
# [Further environment-specific customizations may be required, particularly for certain GPUs or motherboards.]
# -----------------------------------------------------------------------------

set -e

# --- Preliminary Checks -----------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root (sudo)."
  exit 1
fi

if ! command -v update-grub &>/dev/null; then
  echo "Error: 'update-grub' command not found. Are you sure this is a Debian-based system with Grub?"
  exit 2
fi

# --- Detect CPU Vendor ------------------------------------------------------
CPU_VENDOR=$(awk -F: '/vendor_id/ {print $2; exit}' /proc/cpuinfo | tr -d '[:space:]')

if [[ "$CPU_VENDOR" =~ "GenuineIntel" ]]; then
  IOMMU_PARAM="intel_iommu=on"
elif [[ "$CPU_VENDOR" =~ "AuthenticAMD" ]]; then
  IOMMU_PARAM="amd_iommu=on"
else
  echo "Warning: Could not detect Intel or AMD CPU. Defaulting to intel_iommu=on."
  IOMMU_PARAM="intel_iommu=on"
fi

echo "Detected CPU vendor: $CPU_VENDOR"
echo "Will enable IOMMU parameter: $IOMMU_PARAM"

# --- Update /etc/default/grub -----------------------------------------------
GRUB_FILE="/etc/default/grub"

if [[ ! -f "$GRUB_FILE" ]]; then
  echo "Error: $GRUB_FILE not found. Cannot update grub configuration."
  exit 3
fi

# We'll modify GRUB_CMDLINE_LINUX_DEFAULT if the parameter is not already set.
if grep -q "$IOMMU_PARAM" "$GRUB_FILE"; then
  echo "IOMMU parameter ($IOMMU_PARAM) already present in $GRUB_FILE."
else
  echo "Adding $IOMMU_PARAM to GRUB_CMDLINE_LINUX_DEFAULT..."
  sed -i "s/\(^GRUB_CMDLINE_LINUX_DEFAULT=\".*\)\"/\1 $IOMMU_PARAM\"/" "$GRUB_FILE"
fi

# Optionally prompt user to blacklist a GPU driver (e.g. 'nouveau') if they plan to passthrough NVIDIA GPUs
# This step is often necessary for GPU passthrough, but we ask for confirmation:
read -r -p "Do you want to blacklist the 'nouveau' driver for NVIDIA GPU passthrough? [y/N] " RESP
if [[ "$RESP" =~ ^[Yy]$ ]]; then
  MODPROBE_BLACKLIST="/etc/modprobe.d/blacklist.conf"
  if ! grep -q "blacklist nouveau" "$MODPROBE_BLACKLIST" 2>/dev/null; then
    echo "blacklist nouveau" >> "$MODPROBE_BLACKLIST"
    echo "options nouveau modeset=0" >> "$MODPROBE_BLACKLIST"
    echo "NVIDIA 'nouveau' driver has been blacklisted in $MODPROBE_BLACKLIST."
  else
    echo "'nouveau' driver is already blacklisted."
  fi
fi

# --- Update initramfs and Grub ----------------------------------------------
echo "Updating initramfs..."
if command -v update-initramfs &>/dev/null; then
  update-initramfs -u -k all
else
  echo "Warning: 'update-initramfs' not found. Skipping initramfs update."
fi

echo "Updating Grub configuration..."
update-grub

echo "-----------------------------------------------------------------------"
echo "IOMMU has been enabled with parameter: $IOMMU_PARAM"
echo "If you blacklisted nouveau, that change has been applied."
echo "Please reboot the system for changes to take effect."
echo "-----------------------------------------------------------------------"
