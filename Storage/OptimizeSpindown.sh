#!/bin/bash
#
# OptimizeSpindown.sh
#
# A script to install and configure a systemd service for spinning down idle drives in Proxmox (or general Linux),
# as well as a method to uninstall hdparm and remove the service, reverting to default.
#
# Usage:
#   Install/Configure:
#     ./OptimizeSpindown.sh <time_in_minutes> <device_path1> [<device_path2> ...]
#
#   Uninstall (removes hdparm, spindown service, and helper script):
#     ./OptimizeSpindown.sh uninstall
#
# Examples:
#   ./OptimizeSpindown.sh 15 /dev/sda /dev/sdb
#   ./OptimizeSpindown.sh uninstall
#
# Notes:
#   - For spindown values up to 20 minutes, the script uses minutes * 12 for hdparm -S.
#   - For more than 20 minutes, the script clamps to 241 (~30 minutes).
#   - Must be run as root (sudo).
#   - The script sets up a systemd service to run once at boot and apply the hdparm settings.
#   - Running this script with 'uninstall' will remove hdparm, the systemd service, and the helper script.

set -e

# --- Constants ---------------------------------------------------------------
HELPER_SCRIPT="/usr/bin/spindown-logic.sh"
SERVICE_FILE="/etc/systemd/system/spindown.service"

# --- Check if running as root ------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root (sudo)."
  exit 1
fi

# --- Uninstall Mode ----------------------------------------------------------
if [[ "$1" == "uninstall" ]]; then
  echo "Uninstall mode selected. Reverting changes..."

  # Stop and disable the service
  if systemctl is-enabled spindown.service &>/dev/null; then
    systemctl stop spindown.service || true
    systemctl disable spindown.service || true
  fi

  # Remove the systemd service file
  if [[ -f "$SERVICE_FILE" ]]; then
    rm -f "$SERVICE_FILE"
    echo "Removed $SERVICE_FILE"
  fi

  # Remove the helper script
  if [[ -f "$HELPER_SCRIPT" ]]; then
    rm -f "$HELPER_SCRIPT"
    echo "Removed $HELPER_SCRIPT"
  fi

  # Remove hdparm if installed
  if command -v hdparm &>/dev/null; then
    echo "Removing hdparm..."
    # Adjust to your package manager as needed (apt, yum, etc.)
    apt-get remove -y hdparm || echo "Warning: Could not remove hdparm automatically."
  fi

  systemctl daemon-reload
  echo "Uninstall complete. System reverted to default for drive spindown configuration."
  exit 0
fi

# --- Installation Mode -------------------------------------------------------
if ! command -v hdparm &>/dev/null; then
  echo "Installing hdparm..."
  # Adjust to your package manager as needed (apt, yum, etc.)
  apt-get update -y
  apt-get install -y hdparm
fi

# --- Usage / Argument Parsing ------------------------------------------------
if [[ $# -lt 2 ]]; then
  echo "Usage:"
  echo "  $0 <time_in_minutes> <device_path1> [<device_path2> ...]"
  echo "  $0 uninstall"
  exit 2
fi

SPINDOWN_MINUTES="$1"
shift
DEVICES=("$@")

# Simple validation that SPINDOWN_MINUTES is a positive integer
if ! [[ "$SPINDOWN_MINUTES" =~ ^[0-9]+$ ]]; then
  echo "Error: <time_in_minutes> must be a positive integer."
  exit 3
fi

# --- Convert minutes to hdparm -S value --------------------------------------
# For 1-20 minutes, we use (minutes * 12).
# For > 20 minutes, clamp to 241 (which is ~30 minutes).
if [[ "$SPINDOWN_MINUTES" -le 20 ]]; then
  HDPARM_VALUE=$((SPINDOWN_MINUTES * 12))
else
  HDPARM_VALUE=241
fi

# --- Create the helper script in /usr/bin ------------------------------------
cat <<EOF > "$HELPER_SCRIPT"
#!/bin/bash
#
# spindown-logic.sh
#
# Auto-generated script for spinning down drives.
# Do not edit directly; edits may be overwritten by the installation script.

set -e

echo "Applying hdparm spindown settings..."
EOF

for DEV in "${DEVICES[@]}"; do
  cat <<EOF >> "$HELPER_SCRIPT"
hdparm -S $HDPARM_VALUE "$DEV" || echo "Warning: Failed to set spindown on $DEV"
EOF
done

chmod +x "$HELPER_SCRIPT"

# --- Create a systemd service to run once at boot ----------------------------
cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Spin down drives after idle time
After=multi-user.target

[Service]
Type=oneshot
ExecStart=$HELPER_SCRIPT
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable spindown.service
systemctl start spindown.service

echo "Spindown service installed and started."
echo "Drives: ${DEVICES[*]}"
echo "Spindown time (minutes): $SPINDOWN_MINUTES"
echo "hdparm -S value used: $HDPARM_VALUE"
echo "Done."
