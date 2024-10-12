#!/bin/bash

# This script enables the firewall on the datacenter and all nodes within a Proxmox VE cluster.
# It also configures rules to allow communication for VXLAN traffic, SSH (port 22), Proxmox Web GUI (port 8006), and Ceph services.
# It creates an IP set to allow communication between all nodes based on their current IPs.
#
# Usage:
# ./EnableFirewallSetup.sh

# Get the list of all nodes and their IPs
NODES=$(pvecm nodes | awk 'NR>1 {print $2}')
NODE_IPS=()
for NODE in $NODES; do
    IP=$(ssh root@$NODE "hostname -I | awk '{print \$1}'")
    NODE_IPS+=($IP)
    echo "Retrieved IP for node: $NODE - $IP"
done

# Create an IP set for the Proxmox nodes
pvesh create /cluster/firewall/ipset --name proxmox-nodes --comment "IP set for Proxmox nodes"
for IP in "${NODE_IPS[@]}"; do
    pvesh create /cluster/firewall/ipset/proxmox-nodes --cidr $IP/32
    echo "Added $IP to IP set 'proxmox-nodes'."
done

# Allow all traffic within the IP set
pvesh create /cluster/firewall/rules --action ACCEPT --type ipset --source proxmox-nodes --enable 1 --comment "Allow all traffic within Proxmox nodes IP set"

# Get the IP address of the last management device connected
LAST_IP=$(last -i | head -n 1 | awk '{print $3}')

# Allow VXLAN traffic for the node subnet
NODE_SUBNET="$(ip route | grep $(echo ${NODE_IPS[0]} | cut -d. -f1-3) | grep -oE '\b[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}/[0-9]{1,2}\b')"
if [ -n "$NODE_SUBNET" ]; then
    pvesh create /cluster/firewall/rules --action ACCEPT --source $NODE_SUBNET --dest $NODE_SUBNET --proto all --enable 1 --comment "Allow VXLAN traffic for node subnet $NODE_SUBNET"
    echo "Allowed VXLAN traffic for subnet: $NODE_SUBNET."
else
    echo "Node subnet not found. VXLAN rule not added."
fi

# Allow SSH and Proxmox Web GUI access from the management device subnet
MANAGEMENT_SUBNET="$(ip route get $LAST_IP | grep -oP 'src \K[^ ]+' | cut -d. -f1-3).0/24"
if [ -n "$MANAGEMENT_SUBNET" ]; then
    pvesh create /cluster/firewall/rules --action ACCEPT --source $MANAGEMENT_SUBNET --dest + --dport 22 --proto tcp --enable 1 --comment "Allow SSH access from management subnet $MANAGEMENT_SUBNET"
    pvesh create /cluster/firewall/rules --action ACCEPT --source $MANAGEMENT_SUBNET --dest + --dport 8006 --proto tcp --enable 1 --comment "Allow Proxmox Web GUI access from management subnet $MANAGEMENT_SUBNET"
    echo "Allowed SSH and Web GUI access from subnet: $MANAGEMENT_SUBNET."
else
    echo "Management subnet not found. SSH and Web GUI rules not added."
fi

# Allow Ceph communication between nodes
for IP in "${NODE_IPS[@]}"; do
    pvesh create /cluster/firewall/rules --action ACCEPT --source $IP/32 --dest proxmox-nodes --proto tcp --dport 6789 --enable 1 --comment "Allow Ceph Monitor communication from $IP"
    pvesh create /cluster/firewall/rules --action ACCEPT --source $IP/32 --dest proxmox-nodes --proto tcp --dport 6800:7300 --enable 1 --comment "Allow Ceph OSD communication from $IP"
    echo "Allowed Ceph communication for node IP: $IP."
done

# Enable firewall for datacenter
pvesh set /cluster/firewall/options --enable 1
echo "Firewall enabled for datacenter."

# Enable firewall for all nodes
for NODE in $NODES; do
    pvesh set /nodes/$NODE/firewall/options --enable 1
    echo "Firewall enabled for node: $NODE."
done

echo "Firewall setup and enablement completed for all nodes and datacenter!"