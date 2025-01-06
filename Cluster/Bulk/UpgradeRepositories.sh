#!/bin/bash
#
# UpgradeRepositories.sh
#
# A script to:
#   1. Identify the **latest** stable Debian codename that Proxmox currently supports (by querying 
#      http://download.proxmox.com/debian/pve/dists).
#   2. Update your local Proxmox repository configuration to use that codename (e.g., switch
#      from "buster" to "bullseye", or from "bullseye" to "bookworm") if it's different
#      from what you currently have.
#   3. Perform an apt-get update and apt-get dist-upgrade to pull the newest stable Proxmox
#      packages (excluding pvetest).
#
# Usage:
#   ./UpgradeRepositories.sh
#     - Automatically switches your Proxmox repo to the newest stable codename and updates packages.
#
#   ./UpgradeRepositories.sh --dry-run
#     - Shows what changes would be made but does not apply them.
#
#   ./UpgradeRepositories.sh --help
#     - Prints this help message.
#
# Examples:
#   # Standard usage (will update local repo config to newest stable codename and run dist-upgrade):
#   ./UpgradeRepositories.sh
#
#   # Check what would happen without making any changes:
#   ./UpgradeRepositories.sh --dry-run
#
# Description/Notes:
#   - "Latest" stable codename is determined by parsing the directory listing at:
#       http://download.proxmox.com/debian/pve/dists/
#     ignoring "pvetest" or "publickey" directories, then selecting the final entry (which
#     should be the newest stable release).
#
#   - The script will overwrite or create /etc/apt/sources.list.d/pve-latest.list with the
#     new codename if different from your existing config. This assumes a single stable 
#     Proxmox repository file approach. If you use multiple .list files or an enterprise 
#     subscription, adjust accordingly.
#
#   - Make sure you have a valid environment snapshot or backup before switching to a new
#     distribution codename, especially for major version upgrades (e.g., from buster to 
#     bullseye).
#
#   - This script is purely advisory; always confirm that your environment supports upgrading
#     to the new major release, and review official Proxmox documentation for recommended
#     upgrade paths and caveats.
#

# --- Preliminary Checks -----------------------------------------------------
set -e

# Must be root
if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root (sudo)."
  exit 1
fi

# Must be a Proxmox node
if ! command -v pveversion &>/dev/null; then
  echo "Error: 'pveversion' command not found. Are you sure this is a Proxmox node?"
  exit 2
fi

# --- Argument Parsing -------------------------------------------------------
DRY_RUN=false

function display_help() {
  sed -n '2,/^# --- Preliminary/p' "$0" | sed 's/^#//'
}

for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help|-h)
      display_help
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg"
      echo "Use --help for usage."
      exit 3
      ;;
  esac
done

# --- Functions -------------------------------------------------------------

# Query http://download.proxmox.com/debian/pve/dists/ and find the latest stable codename.
#   - Filters out "pvetest" and "publickey".
#   - Assumes the HTML is sorted in ascending order, so the last valid entry is the newest.
function get_latest_proxmox_codename() {
  local TMPFILE
  TMPFILE=$(mktemp)

  curl -s "http://download.proxmox.com/debian/pve/dists/" > "$TMPFILE"
  if [[ ! -s "$TMPFILE" ]]; then
    echo "Error: Could not retrieve Proxmox 'dists' directory listing from the internet."
    rm -f "$TMPFILE"
    exit 4
  fi

  # Extract directory names from the HTML listing. 
  # They appear as <a href="buster/"> or <a href="bullseye/">
  # We:
  #   1) grep for 'href="'
  #   2) parse out the portion before '/"'
  #   3) filter out pvetest, publickey, etc.
  #   4) pick the last line
  local LATEST_CODENAME
  LATEST_CODENAME=$(
    grep -Po '(?<=href=")[^"]+(?=/")' "$TMPFILE" \
      | egrep -v 'pvetest|publickey|^$' \
      | tail -n 1
  )

  rm -f "$TMPFILE"

  if [[ -z "$LATEST_CODENAME" ]]; then
    echo "Error: Unable to parse a valid stable codename from Proxmox dists listing."
    exit 5
  fi

  echo "$LATEST_CODENAME"
}

# Check or create the repository file with the correct codename
function ensure_latest_repo() {
  local LATEST="$1"
  local REPO_FILE="/etc/apt/sources.list.d/pve-latest.list"
  local REPO_LINE="deb http://download.proxmox.com/debian/pve $LATEST pve-no-subscription"

  # If file doesn't exist, create it
  if [[ ! -f "$REPO_FILE" ]]; then
    echo "Proxmox stable repo file not found at $REPO_FILE."
    if [[ "$DRY_RUN" == true ]]; then
      echo "[DRY-RUN] Would create $REPO_FILE with the following line:"
      echo "  $REPO_LINE"
    else
      echo "Creating $REPO_FILE..."
      echo "$REPO_LINE" > "$REPO_FILE"
    fi
    return
  fi

  # If file exists, see if it already references the same codename
  # (We only check for 'deb ...pve <codename> pve-no-subscription')
  if grep -Eq "^deb .*proxmox.com.* $LATEST .*pve-no-subscription" "$REPO_FILE"; then
    echo "The $REPO_FILE already references the latest codename '$LATEST'. No change needed."
  else
    # Otherwise, we rewrite the file with the new line
    echo "Repository file exists but does not match the latest Proxmox codename '$LATEST'."
    if [[ "$DRY_RUN" == true ]]; then
      echo "[DRY-RUN] Would overwrite $REPO_FILE with:"
      echo "  $REPO_LINE"
    else
      echo "Overwriting $REPO_FILE with new repo line for codename '$LATEST'..."
      echo "$REPO_LINE" > "$REPO_FILE"
    fi
  fi
}

# --- Main Script Logic -----------------------------------------------------

echo "Retrieving latest Proxmox stable codename from the internet..."
LATEST_CODENAME=$(get_latest_proxmox_codename)
echo "Latest stable Proxmox codename is: '$LATEST_CODENAME'"

echo "Ensuring local repository file references '$LATEST_CODENAME'..."
ensure_latest_repo "$LATEST_CODENAME"

# Refresh package lists
if [[ "$DRY_RUN" == true ]]; then
  echo "[DRY-RUN] Would run: apt-get update"
else
  echo "Updating package lists..."
  apt-get update
fi

# Now run dist-upgrade to get the newest stable packages
if [[ "$DRY_RUN" == true ]]; then
  echo "[DRY-RUN] Would run: apt-get dist-upgrade -y"
else
  echo "Performing dist-upgrade to pull the newest stable Proxmox packages..."
  apt-get dist-upgrade -y
fi

echo "Repository verification, upgrade, and possible distribution switch are complete."
echo "Script finished successfully."
