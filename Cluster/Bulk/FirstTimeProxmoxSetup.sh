#!/bin/bash
#
# FirstTimeProxmoxSetup.sh
#
# This script performs initial setup for a Proxmox VE cluster:
#   1. Removes enterprise repositories (both Proxmox and Ceph enterprise repos).
#   2. Adds/Enables the free (no-subscription) repository, auto-detecting the correct
#      Debian/Proxmox codename (e.g., buster, bullseye, bookworm).
#   3. Disables the subscription nag for all nodes in the cluster.
#
# Usage:
#   ./FirstTimeProxmoxSetup.sh
#

# --- Function to remove enterprise repository and add the free repository ---
setup_repositories() {
    echo "Setting up repositories on node: $(hostname)"

    # Remove the enterprise repository if it exists
    if [ -f /etc/apt/sources.list.d/pve-enterprise.list ]; then
        rm /etc/apt/sources.list.d/pve-enterprise.list
        echo " - Removed enterprise repository."
    else
        echo " - Enterprise repository not found, skipping removal."
    fi

    # Remove Ceph enterprise repository if it exists
    if [ -f /etc/apt/sources.list.d/ceph-enterprise.list ]; then
        rm /etc/apt/sources.list.d/ceph-enterprise.list
        echo " - Removed Ceph enterprise repository."
    fi

    # Attempt to detect the codename from /etc/os-release
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        CODENAME="${VERSION_CODENAME:-bullseye}" # Default to 'bullseye' if not set
    else
        echo " - /etc/os-release not found. Defaulting to 'bullseye'."
        CODENAME="bullseye"
    fi

    echo " - Detected codename: ${CODENAME}"

    # Check if the no-subscription repo is already in /etc/apt/sources.list
    if ! grep -q "deb http://download.proxmox.com/debian/pve ${CODENAME} pve-no-subscription" /etc/apt/sources.list; then
        echo "deb http://download.proxmox.com/debian/pve ${CODENAME} pve-no-subscription" >> /etc/apt/sources.list
        echo " - Added Proxmox no-subscription repository for '${CODENAME}'."
    else
        echo " - Proxmox no-subscription repository already present."
    fi
}

# --- Function to disable the subscription nag ---
disable_subscription_nag() {
    echo "Disabling subscription nag on node: $(hostname)"
    # Patch the JavaScript file to disable the subscription message
    if [ -f /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js ]; then
        sed -i.bak "s/data.status !== 'Active'/false/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
        echo " - Subscription nag disabled."
    else
        echo " - Proxmox JavaScript file not found, unable to disable subscription nag."
    fi
}

# --- Gather IPs for all cluster nodes (excluding local) from 'pvecm status' ---
# Look for lines starting with "0x" (the node ID), skip the line containing '(local)',
# and print the third field (the IP).
REMOTE_NODES=$(pvecm status | awk '/^0x/ && !/\(local\)/ {print $3}')

# --- Loop through all remote nodes in the cluster, applying the setup via SSH ---
for NODE_IP in $REMOTE_NODES; do
    echo "Connecting to node IP: $NODE_IP"
    ssh root@"$NODE_IP" "$(declare -f setup_repositories); setup_repositories"
    ssh root@"$NODE_IP" "$(declare -f disable_subscription_nag); disable_subscription_nag"
    echo " - Setup completed for node IP: $NODE_IP"
    echo
done

# --- Apply the setup to the local node as well ---
setup_repositories
disable_subscription_nag

echo "Proxmox first-time setup completed for all nodes!"
