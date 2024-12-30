#!/bin/bash
#
# BulkChangeUserPass.sh
#
# This script changes a specified user’s password in a range of LXC containers.
# It uses 'pct exec' to run 'chpasswd' inside each container.
#
# Usage:
#   ./BulkChangeUserPass.sh <start_ct_id> <num_cts> <username> <new_password>
#
# Example:
#   ./BulkChangeUserPass.sh 400 3 root MyNewPass123
#   This updates the root password on CTs 400..402 to 'MyNewPass123'.
#
# Note:
#   - The container(s) must be running for 'pct exec' to succeed.
#   - Adjust logic if you want to handle containers that are stopped.

if [ $# -ne 4 ]; then
  echo "Usage: $0 <start_ct_id> <num_cts> <username> <new_password>"
  exit 1
fi

START_CT_ID="$1"
NUM_CTS="$2"
USERNAME="$3"
NEW_PASSWORD="$4"

echo "=== Starting password update for $NUM_CTS container(s), beginning at CT ID $START_CT_ID ==="
echo "Target user: $USERNAME"

for (( i=0; i<NUM_CTS; i++ )); do
  CURRENT_CT_ID=$((START_CT_ID + i))

  # Check if container exists
  if pct config "$CURRENT_CT_ID" &>/dev/null; then
    echo "Changing password for container $CURRENT_CT_ID..."
    
    # Attempt to run 'chpasswd' inside the container
    pct exec "$CURRENT_CT_ID" -- bash -c "echo \"$USERNAME:$NEW_PASSWORD\" | chpasswd"
    if [ $? -eq 0 ]; then
      echo " - Successfully changed password on CT $CURRENT_CT_ID."
    else
      echo " - Failed to change password on CT $CURRENT_CT_ID (container stopped or other error?)."
    fi
  else
    echo " - Container $CURRENT_CT_ID does not exist. Skipping."
  fi
done

echo "=== Bulk password change process complete! ==="
