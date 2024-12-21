#!/bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <start_vmid|ALL> <end_vmid|target_storage> [target_storage]"
    exit 1
fi

# Assign command-line arguments to variables
START_VMID=$1
END_VMID=$2
TARGET_STORAGE=$3

# If "ALL" is passed, determine the range of VM IDs
if [ "$START_VMID" == "ALL" ]; then
    VMIDS=$(qm list | awk 'NR>1 {print $1}')
    TARGET_STORAGE=$END_VMID
else
    VMIDS=$(seq $START_VMID $END_VMID)
fi

# Function to migrate the Cloud-Init disk
migrate_cloud_init_disk() {
    VMID=$1
    
    # Check if Cloud-Init disk is already on the target storage
    CURRENT_STORAGE=$(qm config $VMID | grep "sata1:" | awk -F ':' '{print $1}' | awk '{print $2}')
    
    if [ "$CURRENT_STORAGE" == "$TARGET_STORAGE" ]; then
        echo "Cloud-Init disk for VM $VMID is already on $TARGET_STORAGE. Skipping migration."
        return
    fi
    
    # Backup Cloud-Init parameters to variables
    echo "Backing up Cloud-Init parameters for VM $VMID..."
    CI_USER=$(qm config $VMID | grep -oP '(?<=ciuser: ).*')
    CI_PASSWORD=$(qm config $VMID | grep -oP '(?<=cipassword: ).*')
    CI_IPCONFIG=$(qm config $VMID | grep -oP '(?<=ipconfig0: ).*')
    CI_NAMESERVER=$(qm config $VMID | grep -oP '(?<=nameserver: ).*')
    CI_SEARCHDOMAIN=$(qm config $VMID | grep -oP '(?<=searchdomain: ).*')

    # Backup SSH keys
    CI_SSHKEYS=$(qm config $VMID | grep -oP '(?<=sshkeys: ).*' | sed 's/%0A/\n/g' | sed 's/%20/ /g')

    if [ -z "$CI_USER" ] && [ -z "$CI_IPCONFIG" ]; then
        echo "VM $VMID does not have Cloud-Init parameters."
        return
    fi

    echo "Cloud-Init parameters backed up successfully."

    # Delete the existing Cloud-Init disk
    echo "Deleting existing Cloud-Init disk for VM $VMID..."
    qm set $VMID -delete sata1
    
    if [ $? -ne 0 ]; then
        echo "Failed to delete Cloud-Init disk for VM $VMID."
        return
    fi
    
    echo "Cloud-Init disk for VM $VMID deleted successfully."

    # Re-create Cloud-Init disk on the target storage
    echo "Re-creating Cloud-Init disk for VM $VMID on $TARGET_STORAGE..."
    qm set $VMID -ide2 $TARGET_STORAGE:cloudinit
    
    if [ $? -ne 0 ]; then
        echo "Failed to create Cloud-Init disk for VM $VMID on $TARGET_STORAGE."
        return
    fi
    
    echo "Cloud-Init disk for VM $VMID created successfully on $TARGET_STORAGE."

    # Restore Cloud-Init parameters
    echo "Restoring Cloud-Init parameters for VM $VMID..."
    
    # Check if SSH key is empty or consists only of whitespace/newlines
    if [[ -n "$CI_SSHKEYS" && "$CI_SSHKEYS" =~ ^ssh-(rsa|dss|ed25519|ecdsa) ]]; then
        TEMP_SSH_FILE="/tmp/sshkeys_$VMID.tmp"
        echo -e "$CI_SSHKEYS" > $TEMP_SSH_FILE

        qm set $VMID \
            -ciuser "$CI_USER" \
            -cipassword "$CI_PASSWORD" \
            -ipconfig0 "$CI_IPCONFIG" \
            -nameserver "$CI_NAMESERVER" \
            -searchdomain "$CI_SEARCHDOMAIN" \
            -sshkeys "$TEMP_SSH_FILE"

        if [ $? -eq 0 ]; then
            echo "Cloud-Init parameters for VM $VMID restored successfully."
        else
            echo "Failed to restore Cloud-Init parameters for VM $VMID."
        fi

        # Clean up temporary SSH key file
        rm $TEMP_SSH_FILE
    else
        echo "Invalid or empty SSH key for VM $VMID. Skipping SSH key restoration."
    fi
}

# Loop through each VMID and migrate the Cloud-Init disk
for VMID in $VMIDS; do
    migrate_cloud_init_disk $VMID
done

echo "Cloud-Init disk migration process completed."