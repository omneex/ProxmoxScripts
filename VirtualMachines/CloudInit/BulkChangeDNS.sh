#!/bin/bash
#
# This script updates the DNS search domain and DNS server for a range of virtual machines (VMs) within a Proxmox VE environment.
# It allows you to set new DNS settings for each VM and regenerates the Cloud-Init image to apply the changes.
#
# Usage:
# ./BulkChangeDNS.sh <start_vm_id> <end_vm_id> <dns_server> <dns_search_domain>
#
# Arguments:
#   start_vm_id - The ID of the first VM to update.
#   end_vm_id - The ID of the last VM to update.
#   dns_server - The DNS server to be set for the VM.
#   dns_search_domain - The DNS search domain to be set for the VM.
#
# Example:
#   ./BulkChangeDNS.sh 400 430 8.8.8.8 example.com

# Check if the minimum required parameters are provided
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <start_vm_id> <end_vm_id> <dns_server> <dns_search_domain>"
    exit 1
fi

# Assigning input arguments
START_VM_ID=$1
END_VM_ID=$2
DNS_SERVER=$3
DNS_SEARCH_DOMAIN=$4

# Loop to update DNS settings for VMs in the specified range
for (( VMID=START_VM_ID; VMID<=END_VM_ID; VMID++ )); do
    # Check if the VM exists
    if qm status $VMID &>/dev/null; then
        echo "Updating DNS settings for VM ID: $VMID"

        # Set the DNS server and DNS search domain using Cloud-Init
        qm set $VMID --nameserver "$DNS_SERVER" --searchdomain "$DNS_SEARCH_DOMAIN"

        # Regenerate the Cloud-Init image
        qm cloudinit dump $VMID
        echo " - Cloud-Init DNS settings updated for VM ID: $VMID."
    else
        echo "VM ID: $VMID does not exist. Skipping..."
    fi

done

echo "Cloud-Init DNS update process completed!"