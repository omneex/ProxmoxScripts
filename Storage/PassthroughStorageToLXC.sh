#!/bin/bash
#
# PassthroughStorageToLXC.sh
#
# A script to pass through a host directory into one or more LXC containers for shared storage.
# It will automatically detect whether each container is unprivileged and convert it to privileged
# if necessary, then mount the specified host directory inside the container with the given permissions.
#
# Usage:
#   ./PassthroughStorageToLXC.sh <host-directory> <permission> <container-IDs...>
#
# Example:
#   ./PassthroughStorageToLXC.sh /mnt/data rw 101 102
#   (Mounts /mnt/data with read-write permissions into containers 101 and 102)
#
#   ./PassthroughStorageToLXC.sh /mnt/logs ro 101 102 103
#   (Mounts /mnt/logs with read-only permissions into containers 101, 102, and 103)
#
# This script will:
#   1. Verify the user is running as root.
#   2. Verify the 'pct' command is available (Proxmox environment).
#   3. Check whether the given directory exists on the host.
#   4. Convert unprivileged containers to privileged if needed.
#   5. Mount the host directory inside each container at /mnt/<basename-of-directory>.
#   6. Apply read-only (ro) or read-write (rw) permissions as specified.
#
# Note:
#   Converting an unprivileged container to privileged requires stopping and restarting the container.
#   Use caution in production environments and test thoroughly before applying.
#

set -e

# --- Preliminary Checks -----------------------------------------------------

if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root (sudo)."
  exit 1
fi

if ! command -v pct &>/dev/null; then
  echo "Error: 'pct' command not found. Are you sure this is a Proxmox node?"
  exit 2
fi

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <host-directory> <permission> <container-IDs...>"
  echo "Example: $0 /mnt/data rw 101 102"
  exit 3
fi

# --- Parse Arguments --------------------------------------------------------

HOST_DIR="$1"
PERMISSION="$2"
shift 2
CONTAINERS=("$@")

# Validate the host directory
if [[ ! -d "$HOST_DIR" ]]; then
  echo "Error: Host directory '$HOST_DIR' does not exist."
  exit 4
fi

# Validate permissions argument
if [[ "$PERMISSION" != "ro" && "$PERMISSION" != "rw" ]]; then
  echo "Error: Permission must be either 'ro' or 'rw'."
  exit 5
fi

# Determine ro flag for pct
RO_FLAG=0
if [[ "$PERMISSION" == "ro" ]]; then
  RO_FLAG=1
fi

# --- Main Logic -------------------------------------------------------------

for CTID in "${CONTAINERS[@]}"; do
  echo "Processing container ID: $CTID"

  # Check if container exists
  if ! pct status "$CTID" &>/dev/null; then
    echo "Warning: LXC container $CTID not found. Skipping."
    continue
  fi

  # Check if container is unprivileged
  UNPRIVILEGED="$(pct config "$CTID" | awk '/^unprivileged:/ {print $2}')"
  if [[ "$UNPRIVILEGED" == "1" ]]; then
    echo "Container $CTID is unprivileged. Converting to privileged..."
    pct set "$CTID" -unprivileged 0 --force
    
    echo "Stopping container $CTID to apply privilege changes..."
    pct stop "$CTID"
    echo "Starting container $CTID after privilege change..."
    pct start "$CTID"
  fi

  # Construct mount point path inside the container
  MOUNT_POINT="/mnt/$(basename "$HOST_DIR")"

  # Find the next available mount point index for this container
  NEXT_MP_INDEX=0
  while pct config "$CTID" | grep -q "^mp${NEXT_MP_INDEX}:"; do
    ((NEXT_MP_INDEX++))
  done

  echo "Mounting host directory '$HOST_DIR' as '$MOUNT_POINT' (ro=$RO_FLAG) in container $CTID..."

  # Apply the mount point configuration
  pct set "$CTID" -mp${NEXT_MP_INDEX} "${HOST_DIR},mp=${MOUNT_POINT},ro=${RO_FLAG},backup=0"

  echo "Successfully mounted in container $CTID."
  echo "------------------------------------------------------"
done

echo "All specified containers processed. Done."
