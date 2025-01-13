#!/bin/bash
#
# BulkChangeIP.sh
#
# Updates the IP addresses of a range of VMs within a Proxmox VE environment.
# Assigns each VM a unique static IP, incrementing from a starting IP address,
# updates their network bridge configuration, and regenerates the Cloud-Init image.
#
# Usage:
#   ./BulkChangeIP.sh <start_vm_id> <end_vm_id> <start_ip/cidr> <bridge> [gateway]
#
# Example usage:
#   # Update IP addresses from VM 400 to 430
#   ./BulkChangeIP.sh 400 430 192.168.1.50/24 vmbr0 192.168.1.1
#
#   # Without specifying a gateway
#   ./BulkChangeIP.sh 400 430 192.168.1.50/24 vmbr0
#
source "$UTILITIES"

check_root
check_proxmox

###############################################################################
# Argument Parsing
###############################################################################
if [ "$#" -lt 4 ]; then
  echo "Usage: $0 <start_vm_id> <end_vm_id> <start_ip/cidr> <bridge> [gateway]"
  exit 1
fi

START_VM_ID="$1"
END_VM_ID="$2"
START_IP_CIDR="$3"
BRIDGE="$4"
GATEWAY="${5:-}"

IFS='/' read -r START_IP SUBNET_MASK <<< "$START_IP_CIDR"

###############################################################################
# Main Logic
###############################################################################
START_IP_INT=$(ip_to_int "$START_IP")

for (( VMID=START_VM_ID; VMID<=END_VM_ID; VMID++ )); do
  currentIpInt=$(( START_IP_INT + VMID - START_VM_ID ))
  newIp="$(int_to_ip "$currentIpInt")"

  if qm status "$VMID" &>/dev/null; then
    echo "Updating VM ID: ${VMID} with IP: ${newIp}"
    qm set "$VMID" --ipconfig0 "ip=${newIp}/${SUBNET_MASK},gw=${GATEWAY}"
    qm set "$VMID" --net0 "virtio,bridge=${BRIDGE}"
    qm cloudinit dump "$VMID"
    echo " - Cloud-Init image regenerated for VM ID: ${VMID}."
  else
    echo "VM ID: ${VMID} does not exist. Skipping..."
  fi
done

echo "IP update process completed!"
