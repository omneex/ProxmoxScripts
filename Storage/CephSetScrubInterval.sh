#!/usr/bin/env bash
#
# CephScrubScheduler.sh
#
# Provides two main modes: local or remote. Each can do 'install' or 'uninstall'.
#
# Usage:
#   # Install locally:
#   ./CephScrubScheduler.sh local install <pool_name> <schedule_type> [time]
#
#   # Uninstall locally:
#   ./CephScrubScheduler.sh local uninstall <pool_name>
#
#   # Install on a remote VM:
#   ./CephScrubScheduler.sh remote install <vm_host> <vm_user> <vm_pass> <pool_name> <schedule_type> [time]
#
#   # Uninstall on a remote VM:
#   ./CephScrubScheduler.sh remote uninstall <vm_host> <vm_user> <vm_pass> <pool_name>
#
# Example schedule_type/time combos:
#   - daily 02:30
#   - 12h       (no time needed)
#   - 6h        (no time needed)
#   - weekly Sun 04:00
#
# On install:
#   1) Disables automatic scrubbing on <pool_name> by setting intervals to 30 days.
#   2) Installs systemd service + timer to manually deep-scrub at the specified schedule.
#
# On uninstall:
#   1) Removes the systemd service + timer + scrub script.
#   2) Reverts the pool’s scrubbing intervals to "defaults" you define below.

###############################################################################
# CONFIG / DEFAULTS
###############################################################################

# Large interval to effectively disable auto-scrubbing:
DISABLE_SCRUB_SECONDS=2592000  # 30 days
# "Default" intervals to revert to on uninstall (adjust to your cluster’s normal):
DEFAULT_SCRUB_MIN=86400   # 24h
DEFAULT_SCRUB_MAX=604800  # 7 days
DEFAULT_DEEP_SCRUB=604800 # 7 days

# Where the local script is placed:
SCRUB_SCRIPT_DIR="/usr/local/bin"
SYSTEMD_DIR="/etc/systemd/system"

###############################################################################
# HELPER: Check usage
###############################################################################
function usage() {
  echo "Usage:"
  echo "  LOCAL INSTALL:   $0 local install <pool_name> <schedule_type> [time]"
  echo "  LOCAL UNINSTALL: $0 local uninstall <pool_name>"
  echo
  echo "  REMOTE INSTALL:  $0 remote install <host> <user> <pass> <pool_name> <schedule_type> [time]"
  echo "  REMOTE UNINSTALL:$0 remote uninstall <host> <user> <pass> <pool_name>"
  echo
  echo "Schedule Types:"
  echo "  daily <HH:MM>   (e.g. daily 02:30)"
  echo "  12h             (every 12 hours from midnight)"
  echo "  6h              (every 6 hours from midnight)"
  echo "  weekly <DAY HH:MM> (e.g. weekly Sun 04:00)"
  exit 1
}

###############################################################################
# HELPER: Derive systemd OnCalendar= expression
###############################################################################
function derive_oncalendar_expression() {
  local schedule_type="$1"
  local schedule_time="$2"

  case "$schedule_type" in
    daily)
      if [[ -z "$schedule_time" ]]; then
        echo "Error: 'daily' schedule requires a time in HH:MM format." >&2
        exit 2
      fi
      echo "*-*-* $schedule_time:00"  # e.g. "*-*-* 02:30:00"
      ;;
    12h)
      echo "0/12:00:00"  # every 12 hours from midnight
      ;;
    6h)
      echo "0/6:00:00"   # every 6 hours from midnight
      ;;
    weekly)
      if [[ -z "$schedule_time" ]]; then
        echo "Error: 'weekly' schedule requires day/time like 'Sun 04:00'." >&2
        exit 2
      fi
      echo "$schedule_time:00"  # e.g. "Sun 04:00:00"
      ;;
    *)
      echo "Error: Unsupported schedule_type '$schedule_type'." >&2
      exit 2
      ;;
  esac
}

###############################################################################
# LOCAL FUNCTIONS (install/uninstall on the same node)
###############################################################################
function local_disable_scrubbing() {
  local pool_name="$1"
  echo "Disabling automatic scrubbing on pool '$pool_name' to $DISABLE_SCRUB_SECONDS seconds..."
  ceph osd pool set "$pool_name" scrub_min_interval $DISABLE_SCRUB_SECONDS
  ceph osd pool set "$pool_name" scrub_max_interval $DISABLE_SCRUB_SECONDS
  ceph osd pool set "$pool_name" deep_scrub_interval $DISABLE_SCRUB_SECONDS
}

function local_revert_scrubbing() {
  local pool_name="$1"
  echo "Reverting scrubbing intervals on pool '$pool_name' to defaults..."
  ceph osd pool set "$pool_name" scrub_min_interval $DEFAULT_SCRUB_MIN
  ceph osd pool set "$pool_name" scrub_max_interval $DEFAULT_SCRUB_MAX
  ceph osd pool set "$pool_name" deep_scrub_interval $DEFAULT_DEEP_SCRUB
}

function local_create_scrub_script() {
  local pool_name="$1"
  local script_path="$SCRUB_SCRIPT_DIR/scrub-${pool_name}.sh"

  echo "Creating scrub script at $script_path ..."
  cat <<EOF > "$script_path"
#!/bin/bash
#
# Auto-generated deep-scrub script for pool '$pool_name'
# by CephScrubScheduler.sh

POOL="$pool_name"
PGS=\$(ceph pg ls-by-pool "\$POOL" -f json | jq -r '.[].pgid')

if [ -z "\$PGS" ]; then
  echo "No PGs found for pool \$POOL, or 'ceph pg ls-by-pool' returned empty."
  exit 0
fi

echo "Starting deep-scrub on pool \$POOL ..."
for PG in \$PGS; do
  echo "  -> Deep-scrubbing PG \$PG"
  ceph pg deep-scrub "\$PG"
done

echo "All deep-scrub commands issued for pool \$POOL."
EOF

  chmod +x "$script_path"
}

function local_create_systemd_units() {
  local pool_name="$1"
  local schedule_type="$2"
  local schedule_time="$3"

  local service_file="$SYSTEMD_DIR/ceph-scrub-${pool_name}.service"
  local timer_file="$SYSTEMD_DIR/ceph-scrub-${pool_name}.timer"

  # Service unit
  echo "Creating systemd service unit at $service_file ..."
  cat <<EOF > "$service_file"
[Unit]
Description=Ceph manual scrub for pool '$pool_name'

[Service]
Type=oneshot
ExecStart=$SCRUB_SCRIPT_DIR/scrub-${pool_name}.sh
EOF

  # Timer unit
  local on_calendar
  on_calendar="$(derive_oncalendar_expression "$schedule_type" "$schedule_time")"

  echo "Creating systemd timer unit at $timer_file ..."
  cat <<EOF > "$timer_file"
[Unit]
Description=Timer for Ceph scrub on pool '$pool_name'

[Timer]
OnCalendar=$on_calendar
Persistent=true

[Install]
WantedBy=timers.target
EOF
}

function local_enable_and_start_timer() {
  local pool_name="$1"
  local timer_name="ceph-scrub-${pool_name}.timer"

  echo "Reloading systemd..."
  systemctl daemon-reload

  echo "Enabling and starting the timer '$timer_name'..."
  systemctl enable "$timer_name"
  systemctl start "$timer_name"

  echo "Done. Timer status:"
  systemctl list-timers --all | grep "$timer_name" || true
}

function local_remove_systemd_units() {
  local pool_name="$1"
  local service_file="$SYSTEMD_DIR/ceph-scrub-${pool_name}.service"
  local timer_file="$SYSTEMD_DIR/ceph-scrub-${pool_name}.timer"
  local script_path="$SCRUB_SCRIPT_DIR/scrub-${pool_name}.sh"

  echo "Stopping and disabling systemd timer for pool '$pool_name'..."
  systemctl stop "ceph-scrub-${pool_name}.timer" 2>/dev/null || true
  systemctl disable "ceph-scrub-${pool_name}.timer" 2>/dev/null || true

  echo "Removing service file: $service_file"
  rm -f "$service_file"

  echo "Removing timer file: $timer_file"
  rm -f "$timer_file"

  echo "Removing scrub script: $script_path"
  rm -f "$script_path"

  systemctl daemon-reload
}

###############################################################################
# REMOTE FUNCTIONS
#
# We use sshpass (password-based SSH) to do:
#   1) Install ceph-common on the remote
#   2) Copy ceph.conf and ceph.client.admin.keyring to /etc/ceph/ on remote
#   3) Copy *this* script to the remote
#   4) Execute "local install" or "local uninstall" on the remote
###############################################################################
function remote_install() {
  local vm_host="$1"
  local vm_user="$2"
  local vm_pass="$3"
  local pool_name="$4"
  local schedule_type="$5"
  local schedule_time="$6"   # might be empty for e.g. 12h or 6h

  if ! command -v sshpass &>/dev/null; then
    echo "Error: sshpass not installed on the local system. Please install it."
    exit 1
  fi

  # 1) Install ceph-common on remote
  echo "Installing ceph-common on remote host '$vm_host'..."
  sshpass -p "$vm_pass" ssh -o StrictHostKeyChecking=no "$vm_user@$vm_host" \
    "sudo apt-get update -y && sudo apt-get install -y ceph-common"

  # 2) Ensure /etc/ceph exists
  sshpass -p "$vm_pass" ssh -o StrictHostKeyChecking=no "$vm_user@$vm_host" \
    "sudo mkdir -p /etc/ceph && sudo chmod 755 /etc/ceph"

  # 3) Copy ceph.conf and ceph.client.admin.keyring
  #    Adjust the paths if your Ceph config files differ
  echo "Copying ceph.conf and ceph.client.admin.keyring to remote..."
  sshpass -p "$vm_pass" scp -o StrictHostKeyChecking=no /etc/ceph/ceph.conf \
    "$vm_user@$vm_host:/tmp/ceph.conf"
  sshpass -p "$vm_pass" scp -o StrictHostKeyChecking=no /etc/ceph/ceph.client.admin.keyring \
    "$vm_user@$vm_host:/tmp/ceph.client.admin.keyring"

  # Move them to /etc/ceph/ with proper perms
  sshpass -p "$vm_pass" ssh -o StrictHostKeyChecking=no "$vm_user@$vm_host" \
    "sudo mv /tmp/ceph.conf /etc/ceph/ && sudo chown root:root /etc/ceph/ceph.conf && sudo chmod 644 /etc/ceph/ceph.conf"
  sshpass -p "$vm_pass" ssh -o StrictHostKeyChecking=no "$vm_user@$vm_host" \
    "sudo mv /tmp/ceph.client.admin.keyring /etc/ceph/ && sudo chown root:root /etc/ceph/ceph.client.admin.keyring && sudo chmod 600 /etc/ceph/ceph.client.admin.keyring"

  # 4) Copy *this* script to remote (in case we want to reuse the same logic)
  local local_script_path="$(realpath "$0")"
  local remote_script_name="CephScrubScheduler-remote.sh" # any temp name
  echo "Copying this script to remote as /tmp/$remote_script_name ..."
  sshpass -p "$vm_pass" scp -o StrictHostKeyChecking=no "$local_script_path" \
    "$vm_user@$vm_host:/tmp/$remote_script_name"

  # 5) Execute "local install" on remote
  echo "Running 'local install' on remote..."
  sshpass -p "$vm_pass" ssh -o StrictHostKeyChecking=no "$vm_user@$vm_host" \
    "sudo bash /tmp/$remote_script_name local install $pool_name $schedule_type '$schedule_time'"
}

function remote_uninstall() {
  local vm_host="$1"
  local vm_user="$2"
  local vm_pass="$3"
  local pool_name="$4"

  if ! command -v sshpass &>/dev/null; then
    echo "Error: sshpass not installed on the local system. Please install it."
    exit 1
  fi

  # We'll assume the script is still there from prior step. If not, we can scp again.
  echo "Uninstalling on remote host '$vm_host'..."
  sshpass -p "$vm_pass" ssh -o StrictHostKeyChecking=no "$vm_user@$vm_host" \
    "sudo bash /tmp/CephScrubScheduler-remote.sh local uninstall $pool_name"

  # Optionally remove the script from remote if you want:
  sshpass -p "$vm_pass" ssh -o StrictHostKeyChecking=no "$vm_user@$vm_host" \
    "sudo rm -f /tmp/CephScrubScheduler-remote.sh"
}

###############################################################################
# MAIN LOGIC
###############################################################################
if [[ $# -lt 2 ]]; then
  usage
fi

MODE="$1"        # "local" or "remote"
ACTION="$2"      # "install" or "uninstall"

case "$MODE" in
  local)
    # local install <pool_name> <schedule_type> [schedule_time]
    # local uninstall <pool_name>
    case "$ACTION" in
      install)
        if [[ $# -lt 4 ]]; then
          usage
        fi
        POOL_NAME="$3"
        SCHEDULE_TYPE="$4"
        SCHEDULE_TIME="$5"  # optional

        # 1) Disable scrubbing
        local_disable_scrubbing "$POOL_NAME"
        # 2) Create scrub script
        local_create_scrub_script "$POOL_NAME"
        # 3) Create systemd units
        local_create_systemd_units "$POOL_NAME" "$SCHEDULE_TYPE" "$SCHEDULE_TIME"
        # 4) Enable and start
        local_enable_and_start_timer "$POOL_NAME"

        echo
        echo "Scrubbing for pool '$POOL_NAME' is disabled (large intervals)."
        echo "A systemd timer is now configured for manual deep-scrub at schedule [$SCHEDULE_TYPE $SCHEDULE_TIME]."
        ;;
      uninstall)
        if [[ $# -lt 3 ]]; then
          usage
        fi
        POOL_NAME="$3"

        # 1) Remove systemd units
        local_remove_systemd_units "$POOL_NAME"
        # 2) Revert scrubbing
        local_revert_scrubbing "$POOL_NAME"

        echo
        echo "Pool '$POOL_NAME' scrubbing intervals reverted to defaults."
        echo "Systemd service/timer removed."
        ;;
      *)
        usage
        ;;
    esac
    ;;
  remote)
    # remote install <host> <user> <pass> <pool_name> <schedule_type> [time]
    # remote uninstall <host> <user> <pass> <pool_name>
    case "$ACTION" in
      install)
        if [[ $# -lt 6 ]]; then
          usage
        fi
        VM_HOST="$3"
        VM_USER="$4"
        VM_PASS="$5"
        POOL_NAME="$6"
        SCHEDULE_TYPE="$7"
        SCHEDULE_TIME="$8"  # might be empty

        remote_install "$VM_HOST" "$VM_USER" "$VM_PASS" "$POOL_NAME" "$SCHEDULE_TYPE" "$SCHEDULE_TIME"
        ;;
      uninstall)
        if [[ $# -lt 6 ]]; then
          usage
        fi
        VM_HOST="$3"
        VM_USER="$4"
        VM_PASS="$5"
        POOL_NAME="$6"

        remote_uninstall "$VM_HOST" "$VM_USER" "$VM_PASS" "$POOL_NAME"
        ;;
      *)
        usage
        ;;
    esac
    ;;
  *)
    usage
    ;;
esac
