#!/bin/bash
#
# GPU_PCI_Passthrough.sh
#
# A script to set up direct passthrough of a specific GPU or PCI device to one or more LXC containers in Proxmox,
# based on a user-supplied PCI device ID (e.g., "01:00.0"). This script does *not* enable access to all PCI devices.
#
# Usage:
#   ./GPU_PCI_Passthrough.sh <PCI_DEVICE_ID> <CTID_1> [<CTID_2> ... <CTID_n>]
#
# Example:
#   ./GPU_PCI_Passthrough.sh 01:00.0 100 101
#
# Notes:
#   1. Ensure VT-d/AMD-Vi (IOMMU) is enabled, and Proxmox is configured for PCI passthrough. This may involve:
#        - Editing /etc/default/grub to include "intel_iommu=on" or "amd_iommu=on"
#        - Updating initramfs or blacklisting certain driver modules
#   2. This script modifies each container’s config file: /etc/pve/lxc/<CTID>.conf
#   3. For GPU passthrough to LXC, you typically need:
#        - lxc.cgroup.devices.allow lines for the specific device (major:minor),
#        - a lxc.mount.entry line for binding the PCI device path inside the container.
#     This script will attempt a minimal approach; you may need additional entries for driver or node-level devices.
#   4. Only "privileged" LXC containers can easily use PCI passthrough. By default, this script will set the container(s) to privileged.
#   5. After making changes, stop and start each container for them to take effect (pct stop <CTID> && pct start <CTID>).
#
# [Further manual edits may be required depending on your environment and GPU driver specifics.]
# -----------------------------------------------------------------------------

set -e

# --- Preliminary Checks -----------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root (sudo)."
  exit 1
fi

if ! command -v pct &>/dev/null; then
  echo "Error: 'pct' command not found. Are you sure this is a Proxmox host?"
  exit 2
fi

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <PCI_DEVICE_ID> <CTID_1> [<CTID_2> ... <CTID_n>]"
  exit 3
fi

PCI_DEVICE_ID="$1"
shift
CTIDS=("$@")

# --- Functions --------------------------------------------------------------

function enable_pci_passthrough_in_container_config() {
  local ctid="$1"
  local config_file="/etc/pve/lxc/${ctid}.conf"

  if [[ ! -f "$config_file" ]]; then
    echo "Warning: $config_file does not exist for CTID $ctid. Skipping..."
    return
  fi

  # Ensure container is privileged
  # (Setting unprivileged=0 forces the container to run as privileged.)
  pct set "$ctid" --unprivileged 0

  # We'll create or update lines in the container config that allow passthrough of the specific PCI device.
  # Typically, you need:
  #   1) lxc.cgroup.devices.allow: c <major> <minor> rwm
  #   2) lxc.mount.entry for the PCI device path in /sys

  # For NVIDIA GPUs, the major device number is usually 195 (c 195:* rwm).
  # For AMD/Intel, adjust as needed.
  if ! grep -q "lxc.cgroup.devices.allow: c 195:* rwm" "$config_file"; then
    echo "lxc.cgroup.devices.allow: c 195:* rwm" >> "$config_file"
  fi

  # Add a mount entry for the specific PCI device path
  local mount_entry="lxc.mount.entry: /sys/bus/pci/devices/0000:$PCI_DEVICE_ID /sys/bus/pci/devices/0000:$PCI_DEVICE_ID none bind,optional,create=dir"
  if ! grep -q "$mount_entry" "$config_file"; then
    echo "$mount_entry" >> "$config_file"
  fi

  echo "Configured PCI passthrough for container $ctid using device $PCI_DEVICE_ID (container is now privileged)."
}

# --- Main Logic -------------------------------------------------------------

for ctid in "${CTIDS[@]}"; do
  # Basic check if container exists
  if ! pct config "$ctid" &>/dev/null; then
    echo "Error: Container $ctid does not exist. Skipping..."
    continue
  fi

  # Attempt to enable PCI passthrough in the container config
  enable_pci_passthrough_in_container_config "$ctid"
done

echo "Done. Please stop and start each container for changes to take effect."
