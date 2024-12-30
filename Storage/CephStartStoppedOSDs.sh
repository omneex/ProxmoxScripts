#!/bin/bash
#
# This script starts all stopped Ceph OSDs within a Proxmox VE environment.
#
# Usage:
# ./StartStoppedOSDs.sh
#
# Example:
#   ./StartStoppedOSDs.sh

# Get the list of all stopped OSDs
STOPPED_OSDS=$(ceph osd tree | awk '/down/ {print $4}')

# Loop through each stopped OSD and start it
for OSD_ID in $STOPPED_OSDS; do
    echo "Starting OSD ID: $OSD_ID"
    ceph osd start osd.$OSD_ID
    if [ $? -eq 0 ]; then
        echo " - OSD ID: $OSD_ID started successfully."
    else
        echo " - Failed to start OSD ID: $OSD_ID."
    fi
done

echo "OSD start process completed!"