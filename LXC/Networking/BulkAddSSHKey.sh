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
#

if [ $# -ne 3 ]; then
  echo "Usage: $0 <start_ct_id> <num_cts> \"<ssh_public_key>\""
  exit 1
fi

START_CT_ID="$1"
NUM_CTS="$2"
SSH_KEY="$3"

echo "=== Starting SSH key addition for $NUM_CTS container(s) ==="
echo " - Starting container ID: $START_CT_ID"
echo " - SSH key to append: $SSH_KEY"

for (( i=0; i<NUM_CTS; i++ )); do
  CURRENT_CT_ID=$((START_CT_ID + i))

  # Check if container exists
  if pct config "$CURRENT_CT_ID" &>/dev/null; then
    echo "Adding SSH key to container $CURRENT_CT_ID..."
    pct exec "$CURRENT_CT_ID" -- bash -c "
      mkdir -p /root/.ssh && \
      chmod 700 /root/.ssh && \
      echo \"$SSH_KEY\" >> /root/.ssh/authorized_keys && \
      chmod 600 /root/.ssh/authorized_keys
    "
    if [ $? -eq 0 ]; then
      echo " - Successfully appended SSH key for CT $CURRENT_CT_ID."
    else
      echo " - Failed to append SSH key for CT $CURRENT_CT_ID (container stopped or other error?)."
    fi
  else
    echo " - Container $CURRENT_CT_ID does not exist. Skipping."
  fi
done

echo "=== Bulk SSH key addition process complete! ==="
