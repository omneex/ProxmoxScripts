#!/bin/bash

# This script guides through the installation and setup of Proxmox with Ceph, ensuring efficient usage of local storage and proper configuration of OSDs.
#
# Usage:
# ./ProxmoxCephSetup.sh <step>
#   step - 'create_osds' to bootstrap auth, create logical volumes, and prepare OSDs,
# Examples:
#   ./ProxmoxCephSetup.sh create_osds

# Check if the step is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <step>"
    echo "step can be 'install', 'setup_ceph', 'create_osds', or 'finalize'"
    exit 1
fi

STEP="$1"

# Function to create OSDs
function create_osds() {
    echo "Creating OSDs on each node..."
    # Step 1: Bootstrap auth
    echo "Bootstrapping auth..."
    ceph auth get client.bootstrap-osd > /var/lib/ceph/bootstrap-osd/ceph.keyring
    echo "Bootstrap auth completed."

    # Step 2: Create new logical volume with remaining free space
    echo "Creating new logical volume..."
    lvcreate -l 100%FREE -n pve/vz
    echo "Logical volume created."

    # Step 3: Prepare and activate the logical volume for OSD
    echo "Preparing and activating the logical volume for OSD..."
    ceph-volume lvm create --data pve/vz
    echo "OSD prepared and activated."
}


# Main logic based on input step
case "$STEP" in
    create_osds)
        create_osds
        ;;
    *)
        echo "Invalid step. Use 'install', 'setup_ceph', 'create_osds', or 'finalize'."
        exit 2
        ;;
esac
