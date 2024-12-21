# Proxmox VE Management Scripts

This repository is dedicated to providing automation scripts for managing Proxmox VE (Virtual Environment) systems efficiently. The scripts are designed for system administrators and DevOps professionals who need to streamline their Proxmox operations.

Explore the scripts for Proxmox VE management on the website:
[Visit the Proxmox VE One-Click Scripts Website](https://coelacant1.github.io/ProxmoxScripts/)

## Getting Started

These instructions will guide you on how to clone this repository and start using the scripts on your Proxmox server for development, testing, or production purposes.

### Prerequisites

Before using these scripts, ensure you have the following:
- Proxmox VE 6.x or newer installed and running, tested on PVE 8.x.
- SSH access to your Proxmox server with appropriate privileges.
- Knowledge of Proxmox operations and Linux shell command execution.
- You have read and understand what the scripts are doing on your system.

### Installation

To execute these scripts on your system, follow these steps:

1. Clone the repository to your Proxmox server or your local machine:
    ```bash
    git clone https://github.com/coelacant1/ProxmoxScripts.git
    ```

2. Navigate into the cloned repository directory:
    ```bash
    cd ProxmoxScripts
    ```

3. Make the scripts executable:
    ```bash
    chmod +x *.sh
    ```

4. Execute a script by following the examples provided in comments within the scripts, adjusting parameters as needed for your environment.

## Usage

Example for description and example commands in each script in this repository:

- **Remote Migrate VMs** (`RemoteMigrateVMs.sh`):
  This script migrates virtual machines (VMs) from a local Proxmox node to a target Proxmox node.
  It utilizes the Proxmox API for migration and requires proper authentication using an API token.
  The script removes any existing Cloud-Init drives before initiating the migration and adjusts VM IDs based on a provided offset.

  Usage:
    ```bash
    ./RemoteMigrateVMs.sh <target_host> <api_token> <fingerprint> <target_storage> <vm_offset> <target_network>
    ```

  Where:
    target_host - The hostname or IP address of the target Proxmox server.
    api_token - The API token used for authentication.
    fingerprint - The SSL fingerprint of the target Proxmox server.
    target_storage - The storage identifier on the target node where VMs will be stored.
    vm_offset - An integer value to offset the VM IDs to avoid conflicts.
    target_network - The network bridge on the target server to connect the VMs.

## Contributing

If you would like to add to the ProxmoxScripts, please follow these steps:

- Fork the repository on GitHub.
- Commit your changes (git commit -m 'Add some YourFeature').
- Push to the branch (git push origin main).
- Submit a pull request through the GitHub website.

## Support

For support, please open an issue in the GitHub repository or contact the maintainers.
