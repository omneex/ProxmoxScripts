#!/bin/bash
#
# EnableCPUScalingGoverner.sh
#
# A script to manage CPU frequency scaling governor on a Proxmox (or general Linux) system.
# Supports three major actions:
#   1. install   - Installs dependencies (cpupower) and this script, and sets an optional default governor.
#   2. remove    - Removes cpupower (if installed via install) and restores system defaults.
#   3. configure - Adjust CPU governor ("performance", "balanced", or "powersave") with optional min/max frequencies.
#
# Usage:
#   ./EnableCPUScalingGoverner.sh install [performance|balanced|powersave] [opts]
#   ./EnableCPUScalingGoverner.sh remove
#   ./EnableCPUScalingGoverner.sh configure [performance|balanced|powersave] [opts]
#
# Common options for "install" or "configure":
#   -m, --min <freq>  Minimum CPU frequency (e.g. 800MHz, 1.2GHz, 1200000)
#   -M, --max <freq>  Maximum CPU frequency (e.g. 2.5GHz, 3.0GHz, 3000000)
#
# Examples:
#   ./EnableCPUScalingGoverner.sh install
#   ./EnableCPUScalingGoverner.sh install performance -m 1.2GHz -M 3.0GHz
#   ./EnableCPUScalingGoverner.sh remove
#   ./EnableCPUScalingGoverner.sh configure balanced
#   ./EnableCPUScalingGoverner.sh configure powersave --min 800MHz
#
# Implementation details:
#   - "balanced" maps to either "ondemand" or "schedutil", whichever is available.
#   - Installing will place this script into /usr/local/bin (so it's globally accessible).
#   - Removing will attempt to restore default scaling governor (assuming 'ondemand' or 'schedutil').
#   - This script will exit on any error (set -e).
#
# Dependencies:
#   - cpupower (recommended) or sysfs-based access to CPU freq scaling.
#
# ----------------------------------------------------------------------------

set -e  # Exit on any error

# --- Globals / Defaults -----------------------------------------------------
SCRIPT_NAME="EnableCPUScalingGoverner.sh"
TARGET_PATH="/usr/local/bin/${SCRIPT_NAME}"

# We'll map 'balanced' to 'ondemand' if available, otherwise 'schedutil'
BALANCED_FALLBACK="ondemand"

if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors ]]; then
  if grep -qw "schedutil" /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors; then
    BALANCED_FALLBACK="schedutil"
  fi
fi

# Our assumed "system default" for remove/uninstall:
SYSTEM_DEFAULT="${BALANCED_FALLBACK}"

# --- Usage Function ---------------------------------------------------------
usage() {
  cat <<EOF
Usage:
  $0 install [performance|balanced|powersave] [options]
  $0 remove
  $0 configure [performance|balanced|powersave] [options]

Options for "install" or "configure":
  -m, --min <freq>  Minimum CPU frequency (e.g. 800MHz, 1.2GHz, 1200000)
  -M, --max <freq>  Maximum CPU frequency (e.g. 2.5GHz, 3.0GHz, 3000000)

Examples:
  $0 install
  $0 install performance -m 1.2GHz -M 3.0GHz
  $0 remove
  $0 configure balanced
  $0 configure powersave --min 800MHz

Description:
  - install:   Installs dependencies (cpupower), copies this script to /usr/local/bin,
               and optionally sets a default governor.
  - remove:    Removes cpupower (if installed by this script) and attempts to restore
               system defaults. Also removes this script from /usr/local/bin.
  - configure: Manually sets CPU governor and optional min/max frequencies.

EOF
  exit 1
}

# --- Helper: set_governor ---------------------------------------------------
# Usage: set_governor <governor> [min_freq] [max_freq]
set_governor() {
  local GOV="$1"
  local MIN_FREQ="$2"
  local MAX_FREQ="$3"

  # If cpupower is installed, try using it first
  if command -v cpupower &>/dev/null; then
    cpupower frequency-set -g "$GOV" >/dev/null 2>&1 || {
      echo "Error: Failed to set governor to '$GOV' via cpupower."
      exit 1
    }
    # Set min/max if provided
    [[ -n "$MIN_FREQ" ]] && cpupower frequency-set -d "$MIN_FREQ" >/dev/null 2>&1
    [[ -n "$MAX_FREQ" ]] && cpupower frequency-set -u "$MAX_FREQ" >/dev/null 2>&1
  else
    echo "Warning: cpupower not found, using sysfs fallback..."

    for cpu_dir in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
      # Set governor
      if [[ -w "$cpu_dir/scaling_governor" ]]; then
        echo "$GOV" > "$cpu_dir/scaling_governor" 2>/dev/null || {
          echo "Error: Failed to set governor via sysfs."
          exit 1
        }
      fi
      # Set min
      if [[ -n "$MIN_FREQ" && -w "$cpu_dir/scaling_min_freq" ]]; then
        echo "$MIN_FREQ" > "$cpu_dir/scaling_min_freq"
      fi
      # Set max
      if [[ -n "$MAX_FREQ" && -w "$cpu_dir/scaling_max_freq" ]]; then
        echo "$MAX_FREQ" > "$cpu_dir/scaling_max_freq"
      fi
    done
  fi

  echo "CPU scaling governor set to '$GOV'."
  [[ -n "$MIN_FREQ" ]] && echo "Min frequency set to: $MIN_FREQ"
  [[ -n "$MAX_FREQ" ]] && echo "Max frequency set to: $MAX_FREQ"
}

# --- Actions ----------------------------------------------------------------

do_install() {
  local GOV="$1"
  local MINFREQ="$2"
  local MAXFREQ="$3"

  echo "Installing cpupower (if not already installed)..."
  if ! command -v cpupower &>/dev/null; then
    # Adjust for Debian/Ubuntu family
    apt-get update -y
    apt-get install -y linux-cpupower
  fi

  echo "Copying script to $TARGET_PATH..."
  # If user invoked script from somewhere else, copy it
  # If the script is already in /usr/local/bin, this overwrites it
  cp -f "$0" "$TARGET_PATH"
  chmod 755 "$TARGET_PATH"

  if [[ -n "$GOV" ]]; then
    echo "Setting governor to '$GOV'..."
    set_governor "$GOV" "$MINFREQ" "$MAXFREQ"
  else
    echo "No governor specified; skipping governor configuration."
  fi

  echo "Install complete."
  exit 0
}

do_remove() {
  echo "Removing cpupower (if it was installed by this script)..."
  # This might remove cpupower entirely if installed, but won't remove if user installed it by other means
  if command -v cpupower &>/dev/null; then
    apt-get remove -y linux-cpupower || echo "Warning: Could not remove linux-cpupower automatically."
  fi

  echo "Restoring system default governor ($SYSTEM_DEFAULT)..."
  set_governor "$SYSTEM_DEFAULT"

  echo "Removing $TARGET_PATH..."
  rm -f "$TARGET_PATH"

  echo "Removal complete."
  exit 0
}

do_configure() {
  local GOV="$1"
  local MINFREQ="$2"
  local MAXFREQ="$3"

  if [[ -z "$GOV" ]]; then
    echo "Error: Missing governor. Must be one of 'performance', 'balanced', or 'powersave'."
    exit 1
  fi

  # If user specified "balanced", map to fallback
  if [[ "$GOV" == "balanced" ]]; then
    GOV="$BALANCED_FALLBACK"
  fi

  set_governor "$GOV" "$MINFREQ" "$MAXFREQ"
  exit 0
}

# --- Main Logic -------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root (sudo)."
  exit 1
fi

if [[ $# -lt 1 ]]; then
  usage
fi

ACTION="$1"
shift

# We'll parse subcommand arguments
GOV_OPT=""
MIN_FREQ=""
MAX_FREQ=""

while [[ $# -gt 0 ]]; do
  case $1 in
    performance|powersave|balanced)
      GOV_OPT="$1"
      shift
      ;;
    -m|--min)
      MIN_FREQ="$2"
      shift 2
      ;;
    -M|--max)
      MAX_FREQ="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Error: Unknown option or argument '$1'"
      usage
      ;;
  esac
done

case "$ACTION" in
  install)
    # If user typed: ./script.sh install [governor] [options]
    do_install "$GOV_OPT" "$MIN_FREQ" "$MAX_FREQ"
    ;;
  remove)
    do_remove
    ;;
  configure)
    do_configure "$GOV_OPT" "$MIN_FREQ" "$MAX_FREQ"
    ;;
  *)
    echo "Error: Unknown action '$ACTION'"
    usage
    ;;
esac
