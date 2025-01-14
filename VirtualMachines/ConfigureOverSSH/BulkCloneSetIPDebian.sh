#!/bin/bash
#
# BulkCloneSetIPDebian.sh
#
# Clones a Debian-based VM multiple times, updates each clone's IP address
# (including the subnet mask in CIDR notation), sets a new default gateway,
# and restarts its network interface. It assumes:
#   1) The template VM is accessible via SSH at the provided template IP (no CIDR).
#   2) /etc/network/interfaces on the template VM includes a line with
#      "address <templateIp>/NN" that can be updated via sed.
#   3) Any existing 'gateway' lines in /etc/network/interfaces will be removed
#      and replaced by the new gateway you specify.
#
# Usage:
#   ./BulkCloneSetIPDebian.sh <templateIp> <startIp/CIDR> <newGateway> <count> <templateId> <baseVmId>
#
# Arguments:
#   templateIp   : The template VM's IP address (e.g. 192.168.1.50).
#   startIpCIDR  : The first clone's IP in CIDR format (e.g. 192.168.1.10/24).
#   newGateway   : The default gateway for all new clones (e.g. 192.168.1.1).
#   count        : Number of clones to create.
#   templateId   : The template VM ID to clone from.
#   baseVmId     : The first new VM ID to assign; subsequent clones increment this.
#
# Example:
#   # Clones VM ID 9000 five times, starting at VM ID 9010.
#   # The template is at 192.168.1.50, the first cloned IP is 192.168.1.10/24,
#   # the gateway is set to 192.168.1.1, and each subsequent clone increments
#   # the final octet by 1.
#   ./BulkCloneSetIPDebian.sh 192.168.1.50 192.168.1.10/24 192.168.1.1 5 9000 9010
#
# Another Example:
#   ./BulkCloneSetIPDebian.sh 192.168.10.50 192.168.10.100/24 192.168.10.1 3 800 810
#

source "$UTILITIES"

###############################################################################
# Check prerequisites and parse arguments
###############################################################################
check_root
check_proxmox

if [ $# -lt 6 ]; then
  echo "Error: Missing arguments."
  echo "Usage: $0 <templateIp> <startIpCIDR> <newGateway> <count> <templateId> <baseVmId>"
  exit 1
fi

templateIpAddr="$1"
startIpCidr="$2"
newGateway="$3"
instanceCount="$4"
templateId="$5"
baseVmId="$6"

# Split the starting IP and mask (e.g., 192.168.1.10/24 -> 192.168.1.10 and 24)
IFS='/' read -r startIpAddrOnly startMask <<< "$startIpCidr"

# Convert the starting IP to an integer for incrementing
ipInt="$( ip_to_int "$startIpAddrOnly" )"

###############################################################################
# Main logic
###############################################################################
for (( i=0; i<instanceCount; i++ )); do
  currentVmId=$(( baseVmId + i ))
  currentIp="$( int_to_ip "$ipInt" )"
  currentIpCidr="$currentIp/$startMask"

  echo "Cloning VM ID \"$templateId\" to new VM ID \"$currentVmId\" with IP \"$currentIpCidr\"..."
  qm clone "$templateId" "$currentVmId" --name "cloned-$currentVmId"
  qm start "$currentVmId"

  echo "Configuring VM ID \"$currentVmId\" to use IP \"$currentIpCidr\" and gateway \"$newGateway\"..."
  # Over SSH to the template VM:
  #   1) Remove existing 'gateway' lines
  #   2) Replace the template IP (and any mask) with the new IP/mask
  #   3) Insert the new gateway line after the 'address' line
  #   4) Restart networking
  ssh "root@$templateIpAddr" "
    sed -i '/\\bgateway\\b/d' /etc/network/interfaces
    sed -i 's|$templateIpAddr/[0-9]\\+|$currentIpCidr|g' /etc/network/interfaces
    sed -i '/address $currentIpCidr/a gateway $newGateway' /etc/network/interfaces
    systemctl restart networking
  "

  # Increment IP by 1 for the next clone
  ipInt=$(( ipInt + 1 ))
done
