#!/bin/bash

# This script performs initial setup for a Proxmox VE cluster. It removes enterprise repositories,
# enables free repositories, adds the latest Ceph enterprise repository, and disables the subscription nag for all nodes in the cluster.
#
# Usage:
# ./FirstTimeProxmoxSetup.sh

# Function to remove enterprise repository and add free repository
setup_repositories() {
    echo "Setting up repositories on node: $(hostname)"
    # Remove the enterprise repository
    if [ -f /etc/apt/sources.list.d/pve-enterprise.list ]; then
        rm /etc/apt/sources.list.d/pve-enterprise.list
        echo " - Removed enterprise repository."
    else
        echo " - Enterprise repository not found, skipping removal."
    fi

    # Add the free repository if not already present
    if ! grep -q "deb http://download.proxmox.com/debian/pve" /etc/apt/sources.list; then
        echo "deb http://download.proxmox.com/debian/pve buster pve-no-subscription" >> /etc/apt/sources.list
        echo " - Added free repository."
    else
        echo " - Free repository already present."
    fi

    # Add the latest Ceph enterprise repository if not already present
    CEPH_RELEASE=$(curl -s https://docs.ceph.com/en/latest/releases/ | grep -oP 'href=".*?/"' | grep -oP '(?<=href=").*?(?=/")' | sort -V | tail -n 1)
    if ! grep -q "deb https://enterprise.proxmox.com/debian/ceph-${CEPH_RELEASE}" /etc/apt/sources.list.d/ceph-enterprise.list 2>/dev/null; then
        echo "deb https://enterprise.proxmox.com/debian/ceph-${CEPH_RELEASE} buster main" > /etc/apt/sources.list.d/ceph-enterprise.list
        echo " - Added Ceph enterprise repository for release: ${CEPH_RELEASE}."
    else
        echo " - Ceph enterprise repository already present for release: ${CEPH_RELEASE}."
    fi
}

# Function to disable the subscription nag
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

# Loop through all nodes in the cluster
for NODE in $(pvecm nodes | awk 'NR>1 {print $2}'); do
    echo "Connecting to node: $NODE"
    ssh root@$NODE "$(declare -f setup_repositories); setup_repositories"
    ssh root@$NODE "$(declare -f disable_subscription_nag); disable_subscription_nag"
    echo " - Setup completed for node: $NODE"
done

# Update the local node
setup_repositories
disable_subscription_nag

echo "Proxmox first-time setup completed for all nodes!"