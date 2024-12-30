#!/usr/bin/env bash
#
# CCPVE.sh
#
# A text-based UI for Coela Can't Proxmox Virtual Environment Scripts.
# Github Repository at: https://github.com/coelacant1/ProxmoxScripts
# Author: Coela Can't! (coelacant1)
#
# Usage:
#   ./CCPVE.sh
#

###############################################################################
# CONFIGURATION
###############################################################################

# Provide the direct URL to your GitHub repo's ZIP file (the "Download ZIP" link):
REPO_ZIP_URL="https://github.com/coelacant1/ProxmoxScripts/archive/refs/heads/main.zip"

TARGET_DIR="/tmp/cc_pve" # Name of the local directory inside /tmp where we’ll extract

DISPLAY_PREFIX="cc_pve" # Prefix to display as the root in the UI
HELP_FLAG="--help" #
LAST_SCRIPT="" # Last script
LAST_OUTPUT="" # Last script output

###############################################################################
# ASCII ART FUNCTION
###############################################################################

show_ascii_art() {
    echo "-----------------------------------------------------------------------------------------"
    echo "                                                                                         "
    echo "    ██████╗ ██████╗ ███████╗██╗      █████╗      ██████╗ █████╗ ███╗   ██╗████████╗██╗   "
    echo "   ██╔════╝██╔═══██╗██╔════╝██║     ██╔══██╗    ██╔════╝██╔══██╗████╗  ██║╚══██╔══╝██║   "
    echo "   ██║     ██║   ██║█████╗  ██║     ███████║    ██║     ███████║██╔██╗ ██║   ██║   ██║   "
    echo "   ██║     ██║   ██║██╔══╝  ██║     ██╔══██║    ██║     ██╔══██║██║╚██╗██║   ██║   ╚═╝   "
    echo "   ╚██████╗╚██████╔╝███████╗███████╗██║  ██║    ╚██████╗██║  ██║██║ ╚████║   ██║   ██╗   "
    echo "    ╚═════╝ ╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝     ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝   ╚═╝   "
    echo "                                                                                         "
    echo "    ██████╗ ██╗   ██╗███████╗    ███████╗ ██████╗██████╗ ██╗██████╗ ████████╗███████╗    "
    echo "    ██╔══██╗██║   ██║██╔════╝    ██╔════╝██╔════╝██╔══██╗██║██╔══██╗╚══██╔══╝██╔════╝    "
    echo "    ██████╔╝██║   ██║█████╗      ███████╗██║     ██████╔╝██║██████╔╝   ██║   ███████╗    "
    echo "    ██╔═══╝ ╚██╗ ██╔╝██╔══╝      ╚════██║██║     ██╔══██╗██║██╔═══╝    ██║   ╚════██║    "
    echo "    ██║      ╚████╔╝ ███████╗    ███████║╚██████╗██║  ██║██║██║        ██║   ███████║    "
    echo "    ╚═╝       ╚═══╝  ╚══════╝    ╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝╚═╝        ╚═╝   ╚══════╝    "
    echo "                                                                                         "
    echo "-----------------------------------------------------------------------------------------"
    echo "   Scripts for advanced task automation in Proxmox Virtual Environment                   "
    echo "   Github: https://github.com/coelacant1/ProxmoxScripts                                  "
    echo "-----------------------------------------------------------------------------------------"
    echo "                                                                                         "
}
###############################################################################
# DOWNLOAD & EXTRACT REPO
###############################################################################

# Clean up any old content
rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"

echo "Downloading repository ZIP..."
if ! wget -q -O "$TARGET_DIR/repo.zip" "$REPO_ZIP_URL"; then
    echo "Error: Failed to download from $REPO_ZIP_URL"
    exit 1
fi

echo "Extracting ZIP..."
if ! unzip -q "$TARGET_DIR/repo.zip" -d "$TARGET_DIR"; then
    echo "Error: Failed to unzip the downloaded file."
    exit 1
fi

# Find the first extracted folder that isn't a dot-folder
BASE_EXTRACTED_DIR=$(find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -type d ! -name ".*" | head -n1)
if [ -z "$BASE_EXTRACTED_DIR" ]; then
    echo "Error: No extracted content found."
    exit 1
fi

echo "Repository extracted into: $BASE_EXTRACTED_DIR"

###############################################################################
# HELPER FUNCTIONS
###############################################################################

# Show the top commented lines from a .sh file, ignoring:
#  1) #!/usr/bin/env bash
#  2) Lines containing only '#'
# until we reach the first line that doesn't begin with '#'.
show_top_comments() {
    local script_path="$1"

    clear
    show_ascii_art
    echo "=== Top Comments for: $(display_current_dir "$script_path") ==="
    echo

    local printing=false
    while IFS= read -r line; do
        # skip #!/usr/bin/env bash
        if [[ "$line" =~ ^#! ]] && [[ "$line" =~ "bash" ]]; then
            continue
        fi
        # skip lines that are only '#'
        if [[ "$line" == "#" ]]; then
            continue
        fi
        # if line starts with '#'
        if [[ "$line" =~ ^# ]]; then
            echo "$line"
            printing=true
        else
            # We hit a line not starting with '#', stop if we started printing
            if [ "$printing" = true ]; then
                break
            fi
        fi
    done <"$script_path"

    echo
    echo "Press Enter to continue."
    read -r
}

# Attempt to find a line like '# ./Script.sh ...' in the top comments
# If found, we consider the script to have usage and return the first such line.
extract_dot_slash_help_line() {
    local script_path="$1"
    local found_line=""

    while IFS= read -r line; do
        # Stop if we've hit a non-# line, so we only look in the top comment block
        if [[ ! "$line" =~ ^# ]]; then
            break
        fi

        # remove leading '#' plus optional spaces
        local stripped="${line#\#}"
        stripped="${stripped#"${stripped%%[![:space:]]*}"}" # remove leading whitespace

        # check if it starts with './'
        if [[ "$stripped" =~ ^\./ ]]; then
            found_line="$stripped"
            break
        fi
    done <"$script_path"

    echo "$found_line"
}

# Show usage by running the script with HELP_FLAG
show_script_usage() {
    local script_path="$1"

    echo "=== Showing usage for: $(display_current_dir "$script_path") ==="

    if [ -x "$script_path" ]; then
        "$script_path" "$HELP_FLAG" 2>&1 || true
    else
        bash "$script_path" "$HELP_FLAG" 2>&1 || true
    fi

    echo
    echo "Press Enter to continue."
    read -r
}

# Converts the absolute path to a display-friendly path starting with DISPLAY_PREFIX
display_current_dir() {
    local current_dir="$1"

    # Remove the BASE_EXTRACTED_DIR prefix
    local relative_dir="${current_dir#$BASE_EXTRACTED_DIR}"

    if [ "$relative_dir" = "$current_dir" ]; then
        # BASE_EXTRACTED_DIR not a prefix (shouldn't happen), display absolute path
        echo "$current_dir"
    elif [ -z "$relative_dir" ]; then
        # At the root
        echo "$DISPLAY_PREFIX"
    else
        # Remove leading slash if present
        relative_dir="${relative_dir#/}"
        echo "$DISPLAY_PREFIX/$relative_dir"
    fi
}

###############################################################################
# RUN SCRIPT FUNCTION
###############################################################################

# If the script has a '# ./script.sh ...' line in its top comments,
# we assume it has usage. If not, we skip usage and run it immediately.
run_script() {
    local script_path="$1"

    clear
    show_ascii_art

    # Check if there's a usage line with '# ./'
    local ds_line
    ds_line=$(extract_dot_slash_help_line "$script_path")

    clear
    show_ascii_art
    if [ -n "$ds_line" ]; then
        echo "Example usage from script comments:"
        echo "  $ds_line"
        echo
    else
        show_top_comments
        echo
    fi

    echo "=== Enter parameters for $(display_current_dir "$script_path") (leave empty to skip or type 'c' to cancel):"
    read -r param_line

    if [ "$param_line" = "c" ]; then
        return # or exit, depending on your desired flow
    fi

    echo
    echo "=== Running: $(display_current_dir "$script_path") $param_line ==="

    IFS=' ' read -r -a param_array <<<"$param_line"
    if [ -x "$script_path" ]; then
        output=$("$script_path" "${param_array[@]}")
    else
        output=$(bash "$script_path" "${param_array[@]}")
    fi

    LAST_SCRIPT="$(display_current_dir "$script_path")"
    LAST_OUTPUT="$output"

    echo "$output"

    echo
    echo "Press Enter to continue."
    read -r
}

###############################################################################
# NAVIGATION FUNCTION
###############################################################################

# navigate <directory>
# - lists subdirectories (non-dot)
# - lists .sh files (non-dot)
# - user picks:
#     b => back
#     e => exit
#     h<N> => show top comments
#     <N> => run script or navigate subdir
# - Displays LAST_OUTPUT if set
navigate() {
    local current_dir="$1"

    while true; do
        clear
        show_ascii_art
        echo "CURRENT DIRECTORY: $(display_current_dir "$current_dir")"
        echo
        echo "Folders and scripts:"
        echo "--------------------"

        # Gather subdirectories (skip .*) and .sh files (skip .*)
        mapfile -t dirs < <(find "$current_dir" -mindepth 1 -maxdepth 1 -type d ! -name ".*" | sort)
        mapfile -t scripts < <(find "$current_dir" -mindepth 1 -maxdepth 1 -type f -name "*.sh" ! -name ".*" | sort)

        local index=1
        declare -A menu_map=()

        # Print directories
        for d in "${dirs[@]}"; do
            local dname
            dname=$(basename "$d")
            echo "$index) $dname/"
            menu_map[$index]="$d"
            ((index++))
        done

        # Print scripts
        for s in "${scripts[@]}"; do
            local sname
            sname=$(basename "$s")
            echo "$index) $sname"
            menu_map[$index]="$s"
            ((index++))
        done

        echo
        echo "--------------------"
        echo
        echo "Type 'h<number>' to show help for a script."
        echo "Type 'b' to go up."
        echo "Type 'e' to exit."
        echo
        echo "--------------------"

        # If LAST_OUTPUT is set, display it
        if [ -n "$LAST_OUTPUT" ]; then
            echo "Last Script Called: $LAST_SCRIPT | Output:"
            echo "$LAST_OUTPUT"
            echo
            echo "--------------------"
        fi

        echo -n "Enter your choice: "
        read -r choice

        # b => go back
        if [[ "$choice" == "b" ]]; then
            if [ "$current_dir" = "$BASE_EXTRACTED_DIR" ]; then
                echo "Exiting..."
                exit 0
            else
                return
            fi
        fi

        if [[ "$choice" == "e" ]]; then
            exit 0
        fi

        # check if user typed hN
        if [[ "$choice" =~ ^h[0-9]+$ ]]; then
            local num="${choice#h}" # remove the 'h'
            if [ -n "${menu_map[$num]}" ]; then
                local selected_path="${menu_map[$num]}"
                if [ -d "$selected_path" ]; then
                    echo "Cannot show top comments for a directory. Press Enter to continue."
                    read -r
                else
                    show_top_comments "$selected_path"
                fi
            else
                echo "Invalid selection. Press Enter to continue."
                read -r
            fi
            continue
        fi

        # numeric choice
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            if [ -z "${menu_map[$choice]}" ]; then
                echo "Invalid numeric choice. Press Enter to continue."
                read -r
                continue
            fi
            local selected_item="${menu_map[$choice]}"

            if [ -d "$selected_item" ]; then
                navigate "$selected_item"
            else
                run_script "$selected_item"
            fi
            continue
        fi

        echo "Invalid input. Press Enter to continue."
        read -r
    done
}

###############################################################################
# LAUNCH
###############################################################################

navigate "$BASE_EXTRACTED_DIR"
