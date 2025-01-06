#!/bin/bash
#
# This script exports Proxmox VM and LXC details from config files in /etc/pve/nodes to a CSV file.
# Usage:
# ./ExportProxmoxResources.sh [lxc|vm|both]

# Determine the type of resource to export
RESOURCE_TYPE="both"
if [[ "$1" == "lxc" || "$1" == "vm" ]]; then
    RESOURCE_TYPE="$1"
elif [[ "$1" == "both" ]]; then
    RESOURCE_TYPE="both"
fi

# Output file
OUTPUT_FILE="cluster_resources.csv"
echo "Node,VMID,Name,CPU,Memory(MB),Disk(GB)" > "$OUTPUT_FILE"

# Function to parse config files for a specific node and type
parse_config_files() {
    local node=$1
    local type=$2

    # Determine the directory based on type
    if [[ "$type" == "both" || "$type" == "vm" ]]; then
        CONFIG_DIR="/etc/pve/nodes/$node/qemu-server"
        if [[ -d "$CONFIG_DIR" ]]; then
            for config_file in "$CONFIG_DIR"/*.conf; do
                [[ -f "$config_file" ]] || continue
                vmid=$(basename "$config_file" .conf)
                name=$(grep -Po '^name: \K.*' "$config_file")
                cpu=$(grep -Po '^cores: \K.*' "$config_file")
                memory=$(grep -Po '^memory: \K.*' "$config_file")
                
                # Calculate total disk size in GB
                disk=$(grep -Po 'size=\K[0-9]+[A-Z]?' "$config_file" | awk '
                    {
                        if ($1 ~ /G$/) sum += substr($1, 1, length($1)-1)
                        else if ($1 ~ /M$/) sum += substr($1, 1, length($1)-1) / 1024
                        else if ($1 ~ /K$/) sum += substr($1, 1, length($1)-1) / (1024 * 1024)
                        else sum += $1 / (1024 * 1024 * 1024)
                    }
                    END {print sum}
                ')

                echo "$node,$vmid,$name,$cpu,$((memory / 1024)),$disk" >> "$OUTPUT_FILE"
            done
        fi
    fi

    if [[ "$type" == "both" || "$type" == "lxc" ]]; then
        CONFIG_DIR="/etc/pve/nodes/$node/lxc"
        if [[ -d "$CONFIG_DIR" ]]; then
            for config_file in "$CONFIG_DIR"/*.conf; do
                [[ -f "$config_file" ]] || continue
                vmid=$(basename "$config_file" .conf)
                name=$(grep -Po '^hostname: \K.*' "$config_file")
                cpu=$(grep -Po '^cores: \K.*' "$config_file")
                memory=$(grep -Po '^memory: \K.*' "$config_file")
                
                # Calculate total disk size in GB
                disk=$(grep -Po 'size=\K[0-9]+[A-Z]?' "$config_file" | awk '
                    {
                        if ($1 ~ /G$/) sum += substr($1, 1, length($1)-1)
                        else if ($1 ~ /M$/) sum += substr($1, 1, length($1)-1) / 1024
                        else if ($1 ~ /K$/) sum += substr($1, 1, length($1)-1) / (1024 * 1024)
                        else sum += $1 / (1024 * 1024 * 1024)
                    }
                    END {print sum}
                ')

                echo "$node,$vmid,$name,$cpu,$((memory / 1024)),$disk" >> "$OUTPUT_FILE"
            done
        fi
    fi
}

# Get a list of all nodes by reading directories in /etc/pve/nodes
NODES=$(ls /etc/pve/nodes)

# Loop through each node and parse config files
for NODE in $NODES; do
    parse_config_files "$NODE" "$RESOURCE_TYPE"
done

echo "Resource export completed! Output saved to $OUTPUT_FILE."
