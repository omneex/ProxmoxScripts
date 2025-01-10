#!/bin/bash
#
# This script guides through the installation and setup of Proxmox with Ceph,
# ensuring efficient usage of local storage and proper configuration of OSDs.
#
# Usage:
#   ./ProxmoxCephSetup.sh <create_osd/clear_local_lvm>
#
# Steps:
#   create_osd    - Bootstrap auth, create LVs, prepare OSDs
#   clear_local_lvm - Delete the local-lvm (pve/data) volume (Destructive!)
#
# Examples:
#   ./ProxmoxCephSetup.sh create_osd
#   ./ProxmoxCephSetup.sh clear_local_lvm
#

# Check if the step is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <step>"
    echo "Steps: 'create_osd', 'clear_local_lvm'"
    exit 1
fi

STEP="$1"

#######################################
# Function to remove local-lvm (pve/data)
# This is a destructive operation.
#######################################
function clear_local_lvm() {
    echo "WARNING: This will remove the local-lvm 'pve/data' and all data within it!"
    read -p "Are you sure you want to proceed? [yes/NO]: " confirmation
    case "$confirmation" in
        yes|YES)
            echo "Removing LVM volume pve/data..."
            lvremove -y pve/data
            echo "Local-lvm 'pve/data' removed successfully."
            ;;
        *)
            echo "Aborting operation."
            ;;
    esac
}

#######################################
# Function to create OSDs
# 1. Bootstrap auth
# 2. Create new logical volume with free space
# 3. Prepare and activate the LV for OSD
#######################################
function create_osd() {
    echo "Creating OSD on node..."

    # Step 1: Bootstrap auth
    echo "Bootstrapping auth..."
    ceph auth get client.bootstrap-osd > /var/lib/ceph/bootstrap-osd/ceph.keyring
    echo "Bootstrap auth completed."

    # Step 2: Create new logical volume with remaining free space
    echo "Creating new logical volume..."
    # Adjust the volume group and name (pve/vz) as needed for your environment
    lvcreate -l 100%FREE -n vz pve
    echo "Logical volume 'pve/vz' created."

    # Step 3: Prepare and activate the logical volume for OSD
    echo "Preparing and activating the logical volume for OSD..."
    ceph-volume lvm create --data pve/vz
    echo "OSD prepared and activated."
}

#######################################
# Main logic based on input step
#######################################
case "$STEP" in
    create_osd)
        create_osd
        ;;
    clear_local_lvm)
        clear_local_lvm
        ;;
    *)
        echo "Invalid step. Use 'create_osd' or 'clear_local_lvm'"
        exit 2
        ;;
esac
