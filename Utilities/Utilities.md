# Utility Functions Quick Description and Usage

check_root
- Checks if the script is run as root, otherwise exits.
- Example usage: check_root
- Example output: Error: This script must be run as root (sudo).

check_proxmox
- Checks if the environment is a Proxmox node, otherwise exits.
- Example usage: check_proxmox
- Example output: Error: 'pveversion' command not found. Are you sure this is a Proxmox node?

install_or_prompt
- Checks if a command is available; if missing, prompts to install or exits if declined.
- Example usage: install_or_prompt "curl"
- Example output: The 'curl' utility is required but is not installed. Would you like to install 'curl' now? [y/N]:

prompt_keep_installed_packages
- Prompts whether to keep or remove packages installed during this session.
- Example usage: prompt_keep_installed_packages
- Example output: The following packages were installed during this session: ... Do you want to KEEP these packages? [Y/n]:

get_remote_node_ips
- Lists IP addresses for remote nodes in the Proxmox cluster.
- Example usage: readarray -t REMOTE_NODES < <( get_remote_node_ips )
- Example output: 172.20.83.22 (newline) 172.20.83.23 ...

check_cluster_membership
- Verifies if the node is part of a Proxmox cluster, otherwise exits.
- Example usage: check_cluster_membership
- Example output: Node is in a cluster named: MyClusterName

get_number_of_cluster_nodes
- Returns the total number of nodes in the Proxmox cluster.
- Example usage: get_number_of_cluster_nodes
- Example output: 3

ip_to_int
- Converts a dotted IPv4 address to its 32-bit integer representation.
- Example usage: ip_to_int "192.168.0.1"
- Example output: 3232235521

int_to_ip
- Converts a 32-bit integer back into a dotted IPv4 address.
- Example usage: int_to_ip 3232235521
- Example output: 192.168.0.1

init_node_mappings
- Builds internal mappings (node ID ↔ IP ↔ name) from cluster status.
- Example usage: init_node_mappings
- Example output: (No direct output; arrays are populated internally.)

get_ip_from_name
- Given a node name, prints its IP or exits if not found.
- Example usage: get_ip_from_name "IHK03"
- Example output: 172.20.83.23

get_name_from_ip
- Given a node IP, prints its node name or exits if not found.
- Example usage: get_name_from_ip "172.20.83.23"
- Example output: IHK03

get_cluster_lxc
- Lists VMIDs of all LXC containers in the entire cluster.
- Example usage: readarray -t ALL_CLUSTER_LXC < <( get_cluster_lxc )
- Example output: 101 (newline) 102 ...

get_server_lxc
- Lists VMIDs of LXC containers on a specific Proxmox server.
- Example usage: readarray -t NODE_LXC < <( get_server_lxc "local" )
- Example output: 201 (newline) 202 ...

get_cluster_vms
- Lists VMIDs of all QEMU VMs in the entire cluster.
- Example usage: readarray -t ALL_CLUSTER_VMS < <( get_cluster_vms )
- Example output: 300 (newline) 301 ...

get_server_vms
- Lists VMIDs of QEMU VMs on a specific Proxmox server.
- Example usage: readarray -t NODE_VMS < <( get_server_vms "local" )
- Example output: 401 (newline) 402 ...