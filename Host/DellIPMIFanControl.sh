#!/bin/bash
#
# DellServerFanControl.sh
#
# An installer/uninstaller script that:
#   - Installs prerequisites.
#   - Asks user for IPMI details and threshold configs.
#   - Writes /etc/dell_fan_control.conf.
#   - Creates /usr/bin/DellServerFanControl-run.sh (background loop).
#   - Creates /etc/systemd/system/DellServerFanControl.service.
#   - Enables/starts or removes the service.
#
# ./DellServerFanControl.sh <install/remove>
#
# Usage:
#   ./DellServerFanControl.sh install
#   ./DellServerFanControl.sh remove
#
# The actual background fan-control runs from /usr/bin/DellServerFanControl-run.sh,
# which is invoked by the systemd service. This script does NOT run the background
# logic itself.

CONFIG_FILE="/etc/dell_fan_control.conf"
SERVICE_FILE="/etc/systemd/system/DellServerFanControl.service"
RUN_SCRIPT="/usr/bin/DellServerFanControl-run.sh"

function check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root (sudo)."
        exit 1
    fi
}

function install_prerequisites() {
    echo "Installing prerequisites..."
    apt-get update -y
    apt-get install -y ipmitool
}

function prompt_user_config() {
    echo "Enter the IPMI host (IP or hostname):"
    read -r IPMI_HOST

    echo "Enter the IPMI username:"
    read -r IPMI_USER

    echo "Enter the IPMI password:"
    read -r IPMI_PASS

    echo "Enter MIN temperature (e.g., 30):"
    read -r MIN_TEMP

    echo "Enter MAX temperature (e.g., 75):"
    read -r MAX_TEMP

    echo "Enter MIN fan speed in percent (e.g., 10):"
    read -r MIN_FAN_SPEED

    echo "Enter MAX fan speed in percent (e.g., 100):"
    read -r MAX_FAN_SPEED

    cat <<EOF > "$CONFIG_FILE"
IPMI_HOST="$IPMI_HOST"
IPMI_USER="$IPMI_USER"
IPMI_PASS="$IPMI_PASS"
MIN_TEMP=$MIN_TEMP
MAX_TEMP=$MAX_TEMP
MIN_FAN_SPEED=$MIN_FAN_SPEED
MAX_FAN_SPEED=$MAX_FAN_SPEED
EOF

    chmod 600 "$CONFIG_FILE"
    echo "Saved configuration to $CONFIG_FILE"
}

function create_run_script() {
    echo "Creating background run script at $RUN_SCRIPT ..."
    cat <<'EOF' > "$RUN_SCRIPT"
#!/bin/bash
#
# /usr/bin/DellServerFanControl-run.sh
#
# This script runs in the background (invoked by systemd) to control Dell server fans via IPMI.
# It loads the config from /etc/dell_fan_control.conf, monitors CPU temps (0Eh, 0Fh),
# and sets fan speeds accordingly.

CONFIG_FILE="/etc/dell_fan_control.conf"

# Load config
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: $CONFIG_FILE not found!"
    exit 1
fi
# shellcheck disable=SC1091
source "$CONFIG_FILE"

# Functions
enable_fan_control() {
    ipmitool -I lanplus -H "$IPMI_HOST" -U "$IPMI_USER" -P "$IPMI_PASS" raw 0x30 0x30 0x01 0x00
}

set_fan_speed() {
    local percentage="$1"
    # Convert 0-100% into 0-255 range
    local raw_speed
    raw_speed=$(awk -v p="$percentage" 'BEGIN { printf "%.0f", p*2.55 }')
    local hex_speed
    hex_speed=$(printf "%02x" "$raw_speed")

    echo "   => Setting fan speed to ${percentage}% (0x${hex_speed})"
    ipmitool -I lanplus -H "$IPMI_HOST" -U "$IPMI_USER" -P "$IPMI_PASS" raw 0x30 0x30 0x02 0xff "0x${hex_speed}"
}

get_temperatures() {
    local output
    output=$(ipmitool -I lanplus -H "$IPMI_HOST" -U "$IPMI_USER" -P "$IPMI_PASS" sdr type temperature || true)

    CPU1_TEMP=""
    CPU2_TEMP=""
    while IFS= read -r line; do
        if [[ "$line" =~ "0Eh" && "$line" =~ "degrees C" ]]; then
            CPU1_TEMP=$(echo "$line" | awk -F'|' '{print $5}' | awk '{print $1}')
        elif [[ "$line" =~ "0Fh" && "$line" =~ "degrees C" ]]; then
            CPU2_TEMP=$(echo "$line" | awk -F'|' '{print $5}' | awk '{print $1}')
        fi
    done <<< "$output"
}

calculate_fan_speed() {
    local temperature="$1"

    # If below MIN_TEMP, fan = MIN_FAN_SPEED
    if (( $(awk -v t="$temperature" -v m="$MIN_TEMP" 'BEGIN{print (t <= m)}') )); then
        echo "$MIN_FAN_SPEED"
        return
    fi

    # If above MAX_TEMP, fan = MAX_FAN_SPEED
    if (( $(awk -v t="$temperature" -v M="$MAX_TEMP" 'BEGIN{print (t >= M)}') )); then
        echo "$MAX_FAN_SPEED"
        return
    fi

    # Otherwise, interpolate linearly
    local slope
    slope=$(awk -v minf="$MIN_FAN_SPEED" -v maxf="$MAX_FAN_SPEED" -v mint="$MIN_TEMP" -v maxt="$MAX_TEMP" '
        BEGIN {
            if ((maxt - mint) == 0) {
                print 0
            } else {
                print (maxf - minf) / (maxt - mint)
            }
        }
    ')

    local fan_speed
    fan_speed=$(awk -v slope="$slope" -v minf="$MIN_FAN_SPEED" -v t="$temperature" -v mint="$MIN_TEMP" '
        BEGIN {
            print minf + slope * (t - mint)
        }
    ')

    # Round
    fan_speed=$(awk -v fs="$fan_speed" 'BEGIN { printf "%.0f", fs }')
    echo "$fan_speed"
}

main_loop() {
    enable_fan_control
    local start_time
    start_time=$(date +%s)

    while true; do
        local now
        now=$(date +%s)
        local elapsed=$((now - start_time))

        # Restart after 24 hours to mimic Python script's behavior
        if (( elapsed >= 86400 )); then
            echo "24 hours elapsed; restarting..."
            exec "$0"
        fi

        get_temperatures
        if [[ -z "$CPU1_TEMP" || -z "$CPU2_TEMP" ]]; then
            echo "Error: Could not read CPU temps. Sleeping 60s..."
            sleep 60
            continue
        fi

        local max_temp
        max_temp=$(awk -v c1="$CPU1_TEMP" -v c2="$CPU2_TEMP" 'BEGIN { if (c1 > c2) print c1; else print c2 }')
        local fan_speed
        fan_speed=$(calculate_fan_speed "$max_temp")

        echo "CPU1: ${CPU1_TEMP}C, CPU2: ${CPU2_TEMP}C => Fan: ${fan_speed}%"
        set_fan_speed "$fan_speed"

        sleep 3
    done
}

main_loop
EOF

    chmod +x "$RUN_SCRIPT"
    echo "Created $RUN_SCRIPT"
}

function create_systemd_service() {
    echo "Creating systemd service at $SERVICE_FILE ..."
    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Dell Server Fan Control Service
After=network.target

[Service]
Type=simple
ExecStart=$RUN_SCRIPT
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

function enable_and_start_service() {
    systemctl daemon-reload
    systemctl enable DellServerFanControl.service
    systemctl start DellServerFanControl.service
    echo "Service 'DellServerFanControl.service' enabled and started."
}

function remove_service_and_files() {
    echo "Stopping and disabling DellServerFanControl.service..."
    systemctl stop DellServerFanControl.service 2>/dev/null || true
    systemctl disable DellServerFanControl.service 2>/dev/null || true

    echo "Removing $SERVICE_FILE..."
    rm -f "$SERVICE_FILE"

    echo "Removing $CONFIG_FILE..."
    rm -f "$CONFIG_FILE"

    echo "Removing $RUN_SCRIPT..."
    rm -f "$RUN_SCRIPT"

    systemctl daemon-reload
    echo "DellServerFanControl removed."
}

function show_usage() {
    echo "Usage: $0 <install|remove>"
    echo "  install - Install prerequisites, prompt for config, create run script & service."
    echo "  remove  - Remove service, config, and run script."
}

### Main
case "$1" in
    install)
        check_root
        install_prerequisites
        prompt_user_config
        create_run_script
        create_systemd_service
        enable_and_start_service
        ;;
    remove)
        check_root
        remove_service_and_files
        ;;
    *)
        show_usage
        ;;
esac
