#!/bin/bash
#
# This script automates the configuration of GPU passthrough on a Linux system (e.g., Proxmox). 
# It adjusts various system configuration files to enable GPU passthrough based on the GPU type (NVIDIA or AMD) 
# and the specific GPU IDs provided. The script modifies GRUB settings for IOMMU, blacklists conflicting drivers, 
# and sets module options necessary for VFIO operation. Suitable for users setting up virtual machines that require 
# direct access to GPU hardware.
#
# Usage:
# ./EnableGPUPassthrough.sh <gpu_type> <gpu_ids>
#   gpu_type - Specify 'nvidia' or 'amd' depending on the GPU manufacturer.
#   gpu_ids - Specify the PCI IDs of the GPUs, formatted as 'vendor_id:device_id'.
# Examples:
#   ./EnableGPUPassthrough.sh nvidia 10de:1e78
#   ./EnableGPUPassthrough.sh amd 1002:67df

# Check if required inputs are provided
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <gpu_type> <gpu_ids>"
    echo "Example: $0 nvidia 10de:1e78"
    echo "Example: $0 amd 1002:67df"
    exit 1
fi

GPU_TYPE=$1
GPU_IDS=$2

# Files to modify
GRUB_CONFIG="/etc/default/grub"
BLACKLIST_CONFIG="/etc/modprobe.d/pveblacklist.conf"
IOMMU_CONFIG="/etc/modprobe.d/iommu_unsafe_interrupts.conf"
VFIO_CONFIG="/etc/modprobe.d/vfio.conf"

echo "Configuring GPU passthrough for $GPU_TYPE..."

# Update GRUB configuration based on GPU type
if ! grep -q "iommu=on" "$GRUB_CONFIG"; then
    if [ "$GPU_TYPE" == "nvidia" ]; then
        SED_STR='s/^GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on"/'
    elif [ "$GPU_TYPE" == "amd" ]; then
        SED_STR='s/^GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on"/'
    else
        echo "Invalid GPU type specified. Use 'nvidia' or 'amd'."
        exit 2
    fi
    sed -i "$SED_STR" $GRUB_CONFIG
    echo "GRUB updated for $GPU_TYPE. Please remember to run 'update-grub' afterwards."
else
    echo "GRUB already configured for IOMMU."
fi

# Update pveblacklist.conf for NVIDIA only
if [ "$GPU_TYPE" == "nvidia" ]; then
    if [ ! -f "$BLACKLIST_CONFIG" ] || ! grep -q "blacklist nvidiafb" "$BLACKLIST_CONFIG"; then
        echo "blacklist nvidiafb" | sudo tee -a $BLACKLIST_CONFIG > /dev/null
        echo "NVIDIA framebuffer driver blacklisted."
    else
        echo "NVIDIA framebuffer blacklist entry already exists."
    fi
fi

# Update iommu_unsafe_interrupts.conf
if [ ! -f "$IOMMU_CONFIG" ] || ! grep -q "allow_unsafe_interrupts=1" "$IOMMU_CONFIG"; then
    echo "options vfio_iommu_type1 allow_unsafe_interrupts=1" | sudo tee -a $IOMMU_CONFIG > /dev/null
    echo "IOMMU unsafe interrupts config updated."
else
    echo "IOMMU config already set."
fi

# Update vfio.conf with GPU IDs
if [ ! -f "$VFIO_CONFIG" ] || ! grep -q "options vfio-pci ids=$GPU_IDS disable_vga=1" "$VFIO_CONFIG"; then
    echo "options vfio-pci ids=$GPU_IDS disable_vga=1" | sudo tee -a $VFIO_CONFIG > /dev/null
    echo "VFIO config updated for GPU IDs."
else
    echo "VFIO config already set for these IDs."
fi

echo "GPU passthrough configuration complete for $GPU_TYPE."
