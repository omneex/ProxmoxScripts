#!/bin/bash

# This script updates the Proxmox scripts repository, handling the repository directory in a case-insensitive manner.
# It performs the following actions:
# 1. Creates a temporary directory for execution if run from within the proxmoxscripts folder.
# 2. Deletes the proxmoxscripts folder.
# 3. Clones the repository.
# 4. Makes scripts executable and runs MakeScriptsExecutable.sh.

# Variables
REPO_URL="https://github.com/coelacant1/proxmoxscripts"
REPO_NAME="proxmoxscripts"

# Get the current directory
CURRENT_DIR=$(pwd)

# Check if the script is being run from inside the proxmoxscripts directory
if [[ "${CURRENT_DIR,,}" == *"${REPO_NAME,,}"* ]]; then
    echo "Detected script is running from inside the $REPO_NAME folder."
    PARENT_DIR=$(dirname "$CURRENT_DIR")
    echo "Switching to parent directory: $PARENT_DIR"
    cd "$PARENT_DIR" || { echo "Failed to navigate to parent directory"; exit 1; }
fi

# Find and delete the existing repository directory (case-insensitive)
REPO_DIR=$(find . -maxdepth 1 -type d -iname "$REPO_NAME" -print -quit)

if [ -n "$REPO_DIR" ]; then
    echo "Deleting existing repository directory: $REPO_DIR"
    rm -rf "$REPO_DIR"
fi

# Clone the repository
echo "Cloning the repository from $REPO_URL..."
git clone "$REPO_URL" || { echo "Failed to clone the repository"; exit 1; }

# Navigate into the cloned repository
cd "$REPO_NAME" || { echo "Failed to navigate to $REPO_NAME"; exit 1; }

# Make the MakeScriptsExecutable.sh script executable
echo "Making MakeScriptsExecutable.sh executable..."
chmod +x MakeScriptsExecutable.sh || { echo "Failed to set executable permission"; exit 1; }

# Run the MakeScriptsExecutable.sh script
echo "Running MakeScriptsExecutable.sh..."
./MakeScriptsExecutable.sh || { echo "Failed to execute MakeScriptsExecutable.sh"; exit 1; }

echo "Update completed successfully."