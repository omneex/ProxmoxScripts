#!/bin/bash

# This script automates the creation of Ceph OSDs for all available devices.

# Loop through all /dev/sd* devices
for device in /dev/sd*; do
    # Check if the device is a block device before attempting to create the OSD
    if [ -b "$device" ]; then
        # Check if the device is unused and a good candidate for a Ceph OSD
        if lsblk -no MOUNTPOINT "$device" | grep -q '^$' && ! pvs | grep -q "$device"; then
            echo "Creating OSD for $device..."

            # Ceph OSD creation command
            if ceph-volume lvm create --data "$device"; then
                echo "Successfully created OSD for $device."
            else
                echo "Failed to create OSD for $device. Continuing with the next device."
            fi
        else
            echo "$device is either in use or not a good candidate for a Ceph OSD. Skipping."
        fi
    else
        echo "$device is not a valid block device. Skipping."
    fi

done

echo "OSD creation process complete."