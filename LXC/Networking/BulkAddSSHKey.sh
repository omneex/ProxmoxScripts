#!/bin/bash
#
# BulkAddSSHKey.sh
#
# This script *appends* an SSH public key to the root user's authorized_keys
# for a range of LXC containers (no existing keys are removed).
#
# Usage:
#   ./BulkAddSSHKey.sh <start_ct_id> <num_cts> "<ssh_public_key>"
#
# Example:
#   ./BulkAddSSHKey.sh 400 3 "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ..."
#   This will append the specified key to containers 400..402.
#
# Notes:
#   - The containers must be *running* for 'pct exec' to work.
#   - If you want to add keys for another user, replace '/root/.ssh' with their home directory.
#   - Must be run as root on a Proxmox node.
#

###############################################################################
# MAIN
###############################################################################

# --- Parse arguments -------------------------------------------------------
if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <start_ct_id> <num_cts> \"<ssh_public_key>\""
  echo "Example:"
  echo "  $0 400 3 \"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ...\""
  exit 1
fi

local start_ct_id="$1"
local num_cts="$2"
local ssh_key="$3"

# --- Basic checks ----------------------------------------------------------
check_proxmox_and_root  # Must be root and on a Proxmox node

# If a cluster check is needed, uncomment:
# check_cluster_membership

# --- Display summary -------------------------------------------------------
echo "=== Starting SSH key addition for $num_cts container(s) ==="
echo " - Starting container ID: $start_ct_id"
echo " - SSH key to append: $ssh_key"

# --- Main Loop -------------------------------------------------------------
for (( i=0; i<num_cts; i++ )); do
  local current_ct_id=$(( start_ct_id + i ))

  # Check if container exists
  if pct config "$current_ct_id" &>/dev/null; then
    echo "Adding SSH key to container $current_ct_id..."
    pct exec "$current_ct_id" -- bash -c "
      mkdir -p /root/.ssh && \
      chmod 700 /root/.ssh && \
      echo \"$ssh_key\" >> /root/.ssh/authorized_keys && \
      chmod 600 /root/.ssh/authorized_keys
    "
    if [[ $? -eq 0 ]]; then
      echo " - Successfully appended SSH key for CT $current_ct_id."
    else
      echo " - Failed to append SSH key for CT $current_ct_id (container stopped or other error?)."
    fi
  else
    echo " - Container $current_ct_id does not exist. Skipping."
  fi
done

echo "=== Bulk SSH key addition process complete! ==="
