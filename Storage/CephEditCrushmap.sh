#!/bin/bash
#
# This script manages the decompilation and recompilation of the Ceph cluster's CRUSH map,
# facilitating custom modifications. The script supports commands to either decompile the 
# current CRUSH map from a compiled state into a human-readable format or recompile it back 
# into a format that can be set in the cluster. It is useful for administrators needing to 
# manually adjust CRUSH maps, which control data placement in the cluster.
#
# Usage:
# ./CephEditCrushmap.sh <command>
#   command - 'decompile' to convert the CRUSH map to a readable format,
#             'compile' to convert it back to a binary format used by Ceph.
# Examples:
#   ./CephEditCrushmap.sh decompile
#   ./CephEditCrushmap.sh compile

# Check if the command is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <command>"
    echo "command can be 'decompile' or 'compile'"
    exit 1
fi

COMMAND="$1"

# Functions for decompiling and recompiling the crush map
function decompile_crush_map() {
    echo "Getting and decompiling the crush map..."
    # Fetch the current crush map
    ceph osd getcrushmap -o /tmp/crushmap.comp

    # Decompile it
    crushtool -d /tmp/crushmap.comp -o /tmp/crushmap.decomp
    echo "Decompiled crush map is at /tmp/crushmap.decomp"
}

function recompile_crush_map() {
    echo "Recompiling and setting the crush map..."
    # Recompile the crush map
    crushtool -c /tmp/crushmap.decomp -o /tmp/crushmap.comp

    # Set it in the cluster
    ceph osd setcrushmap -i /tmp/crushmap.comp
    echo "Crush map has been recompiled and set."
}

# Main logic based on input command
case "$COMMAND" in
    decompile)
        decompile_crush_map
        ;;
    compile)
        recompile_crush_map
        ;;
    *)
        echo "Invalid command. Use 'decompile' or 'compile'."
        exit 2
        ;;
esac
