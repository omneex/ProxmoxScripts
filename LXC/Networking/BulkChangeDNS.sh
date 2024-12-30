#!/bin/bash
#
# BulkChangeDNS.sh
#
# This script updates DNS nameservers for a series of LXC containers.
#
# Usage:
#   ./BulkChangeDNS.sh <start_ct_id> <num_cts> <dns1> [<dns2>] ...
#
# Example:
#   ./BulkChangeDNS.sh 400 3 8.8.8.8 1.1.1.1
#   This updates containers 400..402 to use DNS servers 8.8.8.8 and 1.1.1.1
#
# Note:
#   - You can pass more than two DNS servers if desired. They get appended.
#   - If you want to specify a single DNS server, omit the rest.

if [ $# -lt 3 ]; then
  echo "Usage: $0 <start_ct_id> <num_cts> <dns1> [<dns2> <dns3> ...]"
  exit 1
fi

START_CT_ID="$1"
NUM_CTS="$2"
shift 2  # Move past the first two arguments (start_ct_id, num_cts)

# Remaining arguments are DNS servers
DNS_SERVERS="$*"
echo "DNS servers to set: $DNS_SERVERS"

echo "=== Starting DNS update for $NUM_CTS container(s), beginning at CT ID $START_CT_ID ==="

for (( i=0; i<NUM_CTS; i++ )); do
  CURRENT_CT_ID=$((START_CT_ID + i))

  # Check if container exists
  if pct config "$CURRENT_CT_ID" &>/dev/null; then
    echo "Updating DNS for container $CURRENT_CT_ID to: $DNS_SERVERS"
    pct set "$CURRENT_CT_ID" -nameserver "$DNS_SERVERS"
    if [ $? -eq 0 ]; then
      echo " - Successfully updated DNS for CT $CURRENT_CT_ID."
    else
      echo " - Failed to update DNS for CT $CURRENT_CT_ID."
    fi
  else
    echo " - Container $CURRENT_CT_ID does not exist. Skipping."
  fi
done

echo "=== Bulk DNS change process complete! ==="
