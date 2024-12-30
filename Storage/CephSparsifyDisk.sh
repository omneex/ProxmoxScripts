#!/bin/bash
#
# CephSparsifyVMDisks.sh
#
# This script is designed to sparsify (compact) *all* RBD disk(s) associated with a specific VM
# in a specified Ceph storage pool. By zeroing out unused space in the VM and using the 
# 'rbd sparsify' command, any zeroed blocks are reclaimed in the Ceph pool, making the space 
# available for other uses.
#
# Usage:
#   ./CephSparsifyVMDisks.sh <pool_name> <vm_id>
#     pool_name - The name of the Ceph storage pool where the VM disk(s) reside.
#     vm_id     - The numeric ID of the VM whose disk(s) will be sparsified.
#
# Example:
#   ./CephSparsifyVMDisks.sh mypool 101
#
# Notes:
# 1. This script assumes that the RBD image names follow the convention "vm-<vm_id>-disk-<X>".
#    If your naming convention differs, adjust the grep pattern and/or logic accordingly.
# 2. Ensure that you have already zeroed out the unused space within the VM (e.g., using 
#    sdelete -z in Windows or fstrim in Linux) prior to running this script.
# 3. Verify you have the necessary permissions to run 'rbd sparsify' on the target pool/image.

# Check if both pool_name and vm_id are provided
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <pool_name> <vm_id>"
    exit 1
fi

POOL_NAME=$1
VM_ID=$2

echo "Querying all RBD disks for VM ID '${VM_ID}' in pool '${POOL_NAME}'..."

# List all images in the pool, then filter for those belonging to this VM
# Assumes naming convention: vm-<vm_id>-disk-...
IMAGES=$(rbd ls "${POOL_NAME}" | grep "vm-${VM_ID}-disk-")

if [ -z "${IMAGES}" ]; then
    echo "No disks found for VM ID '${VM_ID}' in pool '${POOL_NAME}'."
    exit 0
fi

echo "Found the following disk(s):"
echo "${IMAGES}"
echo

# Loop through each found image and sparsify it
for IMAGE_NAME in ${IMAGES}; do
    echo "Attempting to sparsify disk '${POOL_NAME}/${IMAGE_NAME}'..."
    rbd sparsify "${POOL_NAME}/${IMAGE_NAME}"
    SPARSIFY_EXIT_CODE=$?

    if [ ${SPARSIFY_EXIT_CODE} -eq 0 ]; then
        echo "Successfully sparsified '${POOL_NAME}/${IMAGE_NAME}'."
    else
        echo "Failed to sparsify '${POOL_NAME}/${IMAGE_NAME}'."
        echo "Please check if the image name is correct and that you have the necessary permissions."
        # You may choose to exit here if one failure should stop the entire script:
        # exit ${SPARSIFY_EXIT_CODE}
    fi
    echo
done

# Script completion message
echo "Disk sparsification process is complete for VM ID '${VM_ID}' in pool '${POOL_NAME}'."
