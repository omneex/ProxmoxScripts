#!/bin/bash
#
# EnableFirewallSetup.sh
#
# This script enables the firewall on the Proxmox VE datacenter and all nodes, then configures:
#   1. An IP set (proxmox-nodes) containing the cluster interface IPs of each node.
#   2. Rules to allow internal node-to-node traffic, Ceph traffic (including msgr2 on port 3300),
#      SSH (22), and Proxmox Web GUI (8006) from a specified management subnet.
#   3. VXLAN traffic (UDP 4789 by default) within the node subnet.
#   4. (Optional) Sets default inbound policy to DROP for the datacenter firewall (commented by default).
#
# Usage:
#   ./EnableFirewallSetup.sh <management_subnet/netmask>
#     management_subnet - e.g. 192.168.1.0/24
#
# Example:
#   ./EnableFirewallSetup.sh 10.0.0.0/24
#
# Notes:
# 1. This script expects passwordless SSH or valid credentials for root on each node.
# 2. If your nodes have multiple network interfaces (e.g., 'vmbr0' for management, 'vmbr1' for storage),
#    adjust the CLUSTER_INTERFACE variable.
# 3. If you have a more complex network (multiple NICs, IPv6, custom VLANs, etc.), further customization
#    may be required.
# 4. Re-running the script should *not* duplicate existing rules or IP set entries, thanks to checks.

###############################################################################
# CONFIGURATION
###############################################################################

# Which interface holds the *cluster/storage* IP address on each node?
# Adjust this to the actual interface in your environment (e.g., "vmbr1" or "eth1").
CLUSTER_INTERFACE="vmbr0"

# By default, we assume VXLAN uses UDP port 4789. Change if your environment differs.
VXLAN_PORT="4789"

###############################################################################
# HELPER FUNCTIONS
###############################################################################

# Check if a given CIDR is already in the proxmox-nodes IP set
function ipset_contains_cidr() {
  local cidr="$1"
  local existing
  # pvesh get /cluster/firewall/ipset/proxmox-nodes returns a JSON array
  # Each entry is an object with "cidr": "x.x.x.x/yy"
  existing=$(
    pvesh get /cluster/firewall/ipset/proxmox-nodes --output-format json 2>/dev/null \
      | jq -r '.[].cidr'
  )

  if echo "$existing" | grep -qx "$cidr"; then
    return 0  # Found
  else
    return 1  # Not found
  fi
}

# Check if a firewall rule with a particular comment already exists
function rule_exists_by_comment() {
  local comment="$1"
  # pvesh get /cluster/firewall/rules returns a JSON array of firewall rules
  # Each entry can have a "comment" field.
  local existing_comments
  existing_comments=$(
    pvesh get /cluster/firewall/rules --output-format json 2>/dev/null \
      | jq -r '.[].comment // empty'
  )
  if echo "$existing_comments" | grep -Fxq "$comment"; then
    return 0
  else
    return 1
  fi
}

# Create a firewall rule only if it doesn't already exist (based on comment)
function create_rule_once() {
  local comment="$1"
  shift
  if rule_exists_by_comment "$comment"; then
    echo " - Rule with comment '$comment' already exists, skipping."
  else
    pvesh create /cluster/firewall/rules "$@" --comment "$comment"
    echo " - Created new rule: $comment"
  fi
}

###############################################################################
# MAIN SCRIPT
###############################################################################

# 1. Parse management subnet
if [ -z "$1" ]; then
  echo "Usage: $0 <management_subnet>"
  echo "Example: $0 192.168.1.0/24"
  exit 1
fi

MANAGEMENT_SUBNET="$1"

echo "Management Subnet: $MANAGEMENT_SUBNET"
echo "Cluster Interface: $CLUSTER_INTERFACE"
echo

# 2. Gather node names and IPs
#    We SSH into each node and get the IP address from the specified interface.
NODES=$(pvecm nodes | awk 'NR>1 {print $2}')
declare -a NODE_IPS=()

echo "=== Collecting IPs for all nodes ==="
for NODE in $NODES; do
  # Adjust this command if you want to filter IPv4 only or prefer a different parsing
  IP=$(ssh -o BatchMode=yes root@"$NODE" \
       "ip -4 addr show dev $CLUSTER_INTERFACE scope global \
        | awk '/inet / {print \$2}' \
        | cut -d'/' -f1 \
        | head -n1")
  if [ -n "$IP" ]; then
    NODE_IPS+=("$IP")
    echo " - Node: $NODE => IP on $CLUSTER_INTERFACE: $IP"
  else
    echo "WARNING: Could not find an IP on interface '$CLUSTER_INTERFACE' for node '$NODE'"
  fi
done
echo

# 3. Create the proxmox-nodes IP set if it doesn’t exist
if ! pvesh get /cluster/firewall/ipset --output-format json 2>/dev/null | jq -r '.[].name' | grep -qx 'proxmox-nodes'; then
  echo "Creating IP set 'proxmox-nodes'..."
  pvesh create /cluster/firewall/ipset --name proxmox-nodes --comment "IP set for Proxmox nodes"
else
  echo "IP set 'proxmox-nodes' already exists, skipping creation."
fi
echo

# 4. Add each node IP to the proxmox-nodes set (if not already there)
echo "=== Adding Node IPs to IP set 'proxmox-nodes' ==="
for IP in "${NODE_IPS[@]}"; do
  if ipset_contains_cidr "${IP}/32"; then
    echo " - $IP/32 is already in the IP set, skipping."
  else
    pvesh create /cluster/firewall/ipset/proxmox-nodes --cidr "$IP/32"
    echo " - Added $IP/32 to IP set 'proxmox-nodes'."
  fi
done
echo

# 5. Allow all traffic within the proxmox-nodes IP set
create_rule_once \
  "Allow all traffic within Proxmox nodes IP set" \
  --action ACCEPT \
  --type ipset \
  --source proxmox-nodes \
  --dest proxmox-nodes \
  --enable 1

echo

# 6. Create a rule to allow SSH and Proxmox Web GUI from the management subnet
create_rule_once \
  "Allow SSH from $MANAGEMENT_SUBNET" \
  --action ACCEPT \
  --source "$MANAGEMENT_SUBNET" \
  --dest '+' \
  --dport 22 \
  --proto tcp \
  --enable 1

create_rule_once \
  "Allow Web GUI from $MANAGEMENT_SUBNET" \
  --action ACCEPT \
  --source "$MANAGEMENT_SUBNET" \
  --dest '+' \
  --dport 8006 \
  --proto tcp \
  --enable 1

# 7. (Optional) If you only want to allow VXLAN traffic (UDP 4789) within the node subnet
#    We'll attempt to guess a common subnet from the first node IP. Or you can simply
#    allow all traffic among nodes for VXLAN. This sample is more targeted.
echo
if [ -n "${NODE_IPS[0]}" ]; then
  # Attempt to derive a route containing that IP
  FIRST_NODE_IP="${NODE_IPS[0]}"
  NODE_SUBNET=$(ip route | grep "$FIRST_NODE_IP" | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}\b' | head -n1)
  if [ -n "$NODE_SUBNET" ]; then
    create_rule_once \
      "Allow VXLAN for $NODE_SUBNET" \
      --action ACCEPT \
      --source "$NODE_SUBNET" \
      --dest "$NODE_SUBNET" \
      --proto udp \
      --dport "$VXLAN_PORT" \
      --enable 1
    echo " - Allowed VXLAN (UDP $VXLAN_PORT) traffic for subnet: $NODE_SUBNET"
  else
    echo "WARNING: Could not determine node subnet from first node IP $FIRST_NODE_IP; skipping VXLAN rule."
  fi
fi
echo

# 8. Allow Ceph communication among nodes
#    This includes ports 6789 (mon, msgr1), 3300 (mon, msgr2), and 6800–7300 (OSDs).
echo "=== Creating Ceph rules among node IPs ==="
for IP in "${NODE_IPS[@]}"; do
  create_rule_once \
    "Allow Ceph MON 6789 from $IP" \
    --action ACCEPT \
    --source "$IP/32" \
    --dest proxmox-nodes \
    --proto tcp \
    --dport 6789 \
    --enable 1

  create_rule_once \
    "Allow Ceph MON 3300 from $IP" \
    --action ACCEPT \
    --source "$IP/32" \
    --dest proxmox-nodes \
    --proto tcp \
    --dport 3300 \
    --enable 1

  create_rule_once \
    "Allow Ceph OSD 6800-7300 from $IP" \
    --action ACCEPT \
    --source "$IP/32" \
    --dest proxmox-nodes \
    --proto tcp \
    --dport 6800:7300 \
    --enable 1
done
echo

# 9. (Optional) Set default policy to DROP incoming and ACCEPT outgoing
#    Commented by default – uncomment if you want a stricter default policy.
# echo "Setting default policy to DROP incoming traffic..."
# pvesh set /cluster/firewall/options --policy_in DROP --policy_out ACCEPT

# 10. Enable firewall for datacenter
pvesh set /cluster/firewall/options --enable 1
echo "Firewall enabled for datacenter."

# 11. Enable firewall for all nodes
for NODE in $NODES; do
  pvesh set "/nodes/$NODE/firewall/options" --enable 1
  echo " - Firewall enabled for node: $NODE."
done

echo
echo "=== Firewall setup and enablement completed for all nodes and datacenter! ==="
