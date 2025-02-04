#!/bin/bash
#
# BulkCloneSetIPDebian.sh
#
# Clones a Debian-based VM multiple times, updates each clone's IP/network,
# sets a default gateway, and restarts networking. Uses SSH with username/password.
# Minimal comments, name prefix added for the cloned VMs.
#
# Usage:
#   ./BulkCloneSetIPDebian.sh <templateIp> <startIpCIDR> <newGateway> <count> <templateId> <baseVmId> <sshUsername> <sshPassword> <vmNamePrefix>
#
# Example:
#   # Clones VM ID 100 five times, starting IP at 172.20.83.100 with mask /24,
#   # gateway 172.20.83.1, base VM ID 200, SSH login root:pass123, prefix "CLOUD-"
#   ./BulkCloneSetIPDebian.sh 172.20.83.22 172.20.83.100/24 172.20.83.1 5 100 200 root pass123 CLOUD-
#

source "$UTILITIES"

###############################################################################
# Function Definitions
###############################################################################
function wait_for_ssh {
  local host="$1"
  local maxAttempts=20
  local delay=3

  for attempt in $(seq 1 "$maxAttempts"); do
    if sshpass -p "$sshPassword" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
       "$sshUsername@$host" exit 2>/dev/null; then
      echo "SSH is up on \"$host\""
      return
    fi
    echo "Attempt $attempt/$maxAttempts: SSH not ready on \"$host\", waiting $delay s..."
    sleep "$delay"
  done

  echo "Error: Could not connect to SSH on \"$host\" after $maxAttempts attempts."
  exit 1
}

###############################################################################
# Environment Checks
###############################################################################
check_root
check_proxmox
install_or_prompt "sshpass"
prompt_keep_installed_packages

###############################################################################
# Argument Parsing
###############################################################################
if [ "$#" -lt 9 ]; then
  echo "Error: Missing arguments."
  echo "Usage: $0 <templateIp> <startIpCIDR> <newGateway> <count> <templateId> <baseVmId> <sshUsername> <sshPassword> <vmNamePrefix>"
  exit 1
fi

templateIpAddr="$1"
startIpCidr="$2"
newGateway="$3"
instanceCount="$4"
templateId="$5"
baseVmId="$6"
sshUsername="$7"
sshPassword="$8"
vmNamePrefix="$9"

IFS='/' read -r startIpAddrOnly startMask <<<"$startIpCidr"
ipInt="$(ip_to_int "$startIpAddrOnly")"

###############################################################################
# Main Logic
###############################################################################
for ((i=0; i<instanceCount; i++)); do
  currentVmId=$((baseVmId + i))
  currentIp="$(int_to_ip "$ipInt")"
  currentIpCidr="$currentIp/$startMask"

  echo "Cloning VM ID \"$templateId\" to new VM ID \"$currentVmId\" with IP \"$currentIpCidr\"..."
  qm clone "$templateId" "$currentVmId" --name "${vmNamePrefix}${currentVmId}"
  qm start "$currentVmId"

  wait_for_ssh "$templateIpAddr"

  sshpass -p "$sshPassword" ssh -o StrictHostKeyChecking=no "$sshUsername@$templateIpAddr" bash -s <<EOF
sed -i '/\bgateway\b/d' /etc/network/interfaces
sed -i "s#${templateIpAddr}/[0-9]\\+#${currentIpCidr}#g" /etc/network/interfaces
sed -i "\#address ${currentIpCidr}#a gateway ${newGateway}" /etc/network/interfaces
TAB="\$(printf '\\t')"
sed -i "s|^[[:space:]]*gateway\\(.*\\)|\${TAB}gateway\\1|" /etc/network/interfaces
EOF

  sshpass -p "$sshPassword" ssh -o StrictHostKeyChecking=no "$sshUsername@$templateIpAddr" \
    "nohup sh -c 'sleep 2; systemctl restart networking' >/dev/null 2>&1 &"

  wait_for_ssh "$currentIp"
  ipInt=$((ipInt + 1))
done

###############################################################################
# Testing status
###############################################################################
# Tested single-node
# Tested multi-node
