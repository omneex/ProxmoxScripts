#!/bin/bash
#
# CephCreateOSDsAllNodes.sh
#
# This script runs on all nodes in the Proxmox cluster to automatically create Ceph OSDs 
# on all unused block devices (e.g., /dev/sd*, /dev/nvme*, /dev/hd*).
#
# Usage:
#   ./CephCreateOSDsAllNodes.sh
#
# Requirements/Assumptions:
#   1. You have passwordless SSH or valid SSH keys for root on all nodes.
#   2. 'pvecm nodes' works and returns the node list.
#   3. Each node already has Ceph installed and configured sufficiently to run 'ceph-volume'.
#   4. Verify that any device you want to skip is either already mounted or recognized in pvs, 
#      or extend the checks if needed.
#

###############################################################################
# FUNCTION: create_osds
# This function will:
#   - Iterate over all potential block devices (/dev/sd*, /dev/nvme*, /dev/hd*)
#   - Check if the device is valid (-b)
#   - Check if it's unused (not mounted and not in pvs)
#   - Attempt to create a Ceph OSD via ceph-volume
###############################################################################
create_osds() {
  echo "=== Checking for devices on node: $(hostname) ==="

  # Here we include /dev/sd*, /dev/nvme*, /dev/hd* as examples.
  # You can add more patterns if needed (e.g., /dev/vd* for virtio).
  for device in /dev/sd* /dev/nvme* /dev/hd* 2>/dev/null; do

    # Skip if the glob doesn't match anything
    [ -e "$device" ] || continue

    # Check if the device is actually a block device
    if [ -b "$device" ]; then

      # Check if the device is unused:
      #   1. No mountpoint
      #   2. Not present in pvs (i.e., not already an LVM PV)
      if lsblk -no MOUNTPOINT "$device" | grep -q '^$' && ! pvs 2>/dev/null | grep -q "$device"; then
        echo "Creating OSD for $device..."
        
        if ceph-volume lvm create --data "$device"; then
          echo "Successfully created OSD for $device."
        else
          echo "Failed to create OSD for $device. Continuing with the next device."
        fi

      else
        echo "$device is in use (mounted or found in pvs). Skipping."
      fi

    else
      # Not a block device (or doesn't exist)
      echo "$device is not a valid block device. Skipping."
    fi

  done

  echo "=== OSD creation process complete on node: $(hostname) ==="
}


###############################################################################
# MAIN SCRIPT
###############################################################################

# 1. Gather the list of nodes from the cluster
# We skip the header line (NR>1), picking the 2nd column for node names
NODES=$(pvecm nodes | awk 'NR>1 {print $2}')

if [ -z "$NODES" ]; then
  echo "No nodes found via 'pvecm nodes'. Are you in a Proxmox cluster?"
  exit 1
fi

# 2. Loop over each node and run the create_osds function via SSH
echo "=== Starting OSD creation on all nodes ==="
for NODE in $NODES; do
  echo "=> Connecting to node: $NODE"

  # We'll pass the function definition and then invoke it remotely
  ssh root@"$NODE" "$(typeset -f create_osds); create_osds"
done

echo "=== Ceph OSD creation process completed on all nodes! ==="
