#!/bin/bash
#
# EnablePWMFanControl.sh
#
# A script to manage system fans using fancontrol for efficient cooling management.
# This script allows you to install or uninstall a PWM-based fan control service
# with minimum and maximum temperature thresholds, as well as minimum and maximum
# fan speeds for interpolation.
#
# Usage:
#   ./EnablePWMFanControl.sh install [<min-temp> <max-temp> <min-pwm> <max-pwm>]
#   ./EnablePWMFanControl.sh uninstall
#
# Examples:
#   ./EnablePWMFanControl.sh install      # Installs fancontrol with default thresholds
#   ./EnablePWMFanControl.sh install 35 80 50 255
#   ./EnablePWMFanControl.sh uninstall    # Uninstalls fancontrol and reverts to default
#
# -------------------------------------------------------------------------------
# This script:
#   1) Installs the 'fancontrol' package if needed.
#   2) Creates or updates /etc/fancontrol with min/max temp and min/max PWM settings.
#   3) Enables and starts the fancontrol systemd service.
#   4) Allows uninstalling fancontrol and reverting system fans to defaults.
#
# Make sure to run this script on a Proxmox node that has direct access to PWM
# fan control via /sys/class/hwmon/ or similar device paths.
# -------------------------------------------------------------------------------

set -e  # Exit immediately on any non-zero command return

# --- Preliminary Checks ---------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root (sudo)."
  exit 1
fi

if ! command -v apt-get &>/dev/null; then
  echo "Error: 'apt-get' command not found. This script is intended for Debian-based systems."
  exit 2
fi

# --- Helper Functions -----------------------------------------------------------

show_usage() {
  echo "Usage:"
  echo "  $0 install [<min-temp> <max-temp> <min-pwm> <max-pwm>]"
  echo "  $0 uninstall"
  echo
  echo "Examples:"
  echo "  $0 install"
  echo "  $0 install 35 80 50 255"
  echo "  $0 uninstall"
}

# Installs fancontrol and configures the PWM settings
install_fancontrol() {
  local MIN_TEMP=$1
  local MAX_TEMP=$2
  local MIN_PWM=$3
  local MAX_PWM=$4

  echo "Installing fancontrol package..."
  apt-get update -y
  apt-get install -y fancontrol

  # Attempt to detect the hwmon device automatically (naive approach).
  # Adjust or hard-code as necessary for your environment.
  # Typically the user would run 'sensors' or 'pwmconfig' to identify device paths.
  local HWMON_DEVICE
  HWMON_DEVICE="$(ls /sys/class/hwmon/ | head -n1)"
  if [[ -z "$HWMON_DEVICE" ]]; then
    echo "Error: No hwmon device found. Ensure your system supports PWM fan control."
    exit 3
  fi

  # Default fancontrol config location
  local FANCONTROL_CONF="/etc/fancontrol"

  echo "Generating $FANCONTROL_CONF with the following parameters:"
  echo "  Min Temp  : $MIN_TEMP"
  echo "  Max Temp  : $MAX_TEMP"
  echo "  Min PWM   : $MIN_PWM"
  echo "  Max PWM   : $MAX_PWM"
  echo "  Hwmon Dev : $HWMON_DEVICE"

  cat <<EOF > "$FANCONTROL_CONF"
#------------------------------------------------------------------------------
# /etc/fancontrol
# Created by EnablePWMFanControl.sh
#
# This config assumes a single PWM channel and a single temperature sensor
# for demonstration. Adjust to match your system's sensors (see pwmconfig).
#------------------------------------------------------------------------------

INTERVAL=10

# The device path for hardware monitoring
DEVPATH=hwmon0=/sys/class/hwmon/$HWMON_DEVICE
DEVNAME=hwmon0=$(cat /sys/class/hwmon/"$HWMON_DEVICE"/name 2>/dev/null || echo "unknown")

# Assign sensors
# Example: If your pwm is "pwm1" and temp sensor is "temp1_input"
FCTEMPS=hwmon0/pwm1=hwmon0/temp1_input
FCFANS=hwmon0/pwm1=hwmon0/fan1_input

# Temperature and PWM settings
# These define the min->max temperature range and the corresponding
# min->max PWM speeds for fancontrol to interpolate.
MINTEMP=hwmon0/pwm1=$MIN_TEMP
MAXTEMP=hwmon0/pwm1=$MAX_TEMP
MINPWM=hwmon0/pwm1=$MIN_PWM
MAXPWM=hwmon0/pwm1=$MAX_PWM

# Start/stop thresholds (optional, used for hysteresis)
MINSTOP=hwmon0/pwm1=$MIN_PWM
MINSTART=hwmon0/pwm1=$(($MIN_PWM + 10))

EOF

  echo "Enabling and starting fancontrol service..."
  systemctl enable fancontrol
  systemctl restart fancontrol
  echo "fancontrol installation and configuration complete."
}

# Uninstalls fancontrol and reverts to default
uninstall_fancontrol() {
  echo "Stopping and disabling fancontrol service..."
  systemctl stop fancontrol || true
  systemctl disable fancontrol || true

  echo "Removing fancontrol package..."
  apt-get remove -y --purge fancontrol
  apt-get autoremove -y

  local FANCONTROL_CONF="/etc/fancontrol"
  if [[ -f "$FANCONTROL_CONF" ]]; then
    echo "Removing $FANCONTROL_CONF..."
    rm -f "$FANCONTROL_CONF"
  fi

  echo "fancontrol uninstalled. System fans are reverted to default."
}

# --- Main -----------------------------------------------------------------------
ACTION="$1"
case "$ACTION" in
  install)
    # Default values if none are provided
    MIN_TEMP="${2:-30}"
    MAX_TEMP="${3:-70}"
    MIN_PWM="${4:-60}"
    MAX_PWM="${5:-255}"

    install_fancontrol "$MIN_TEMP" "$MAX_TEMP" "$MIN_PWM" "$MAX_PWM"
    ;;
  uninstall)
    uninstall_fancontrol
    ;;
  *)
    show_usage
    exit 1
    ;;
esac
