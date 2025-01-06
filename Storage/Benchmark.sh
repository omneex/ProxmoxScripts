#!/bin/bash
#
# Benchmark.sh
#
# A script to measure disk performance across local, ZFS, or Ceph storage using 'fio'.
# This script installs fio if it's missing, asks if the user wants to keep it afterward,
# runs a series of read/write benchmarks, displays key results, and optionally exports
# the full results to CSV.
#
# Usage:
#   ./Benchmark.sh <test-directory>
#
# Example:
#   ./Benchmark.sh /tmp/fio_test
#
# Note:
#   - Run as root for the most accurate results (especially if testing privileged directories).
#   - This script may install and remove packages on your system.

set -e

# --- Preliminary Checks -----------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "Error: This script should ideally be run as root (sudo) for accurate results."
fi

# Check if 'jq' is installed for JSON parsing (not mandatory, but recommended)
JQ_INSTALLED=true
if ! command -v jq &>/dev/null; then
  JQ_INSTALLED=false
fi

# Determine if 'fio' is installed; if not, prompt to install
FIO_INSTALLED=true
if ! command -v fio &>/dev/null; then
  FIO_INSTALLED=false
  read -r -p "fio not found. Would you like to install it now? (y/N): " INSTALL_FIO
  if [[ "$INSTALL_FIO" =~ ^[Yy]$ ]]; then
    apt-get update && apt-get install -y fio
    FIO_INSTALLED=true
  else
    echo "Error: 'fio' is required to run this benchmark."
    exit 1
  fi
fi

TEST_DIR="$1"

if [[ -z "$TEST_DIR" ]]; then
  echo "Usage: $0 <test-directory>"
  exit 1
fi

# Create test directory if it doesn't exist
mkdir -p "$TEST_DIR"

# --- FIO Benchmark Functions -----------------------------------------------
# We'll run simple read and write tests at 4K block size, random IO.

run_fio_test() {
  local job_name="$1"
  local rw_mode="$2"
  local result_file="$3"

  fio --directory="$TEST_DIR" \
      --name="$job_name" \
      --rw="$rw_mode" \
      --direct=1 \
      --bs=4k \
      --iodepth=32 \
      --numjobs=1 \
      --time_based \
      --runtime=10 \
      --group_reporting=1 \
      --output-format=json \
      --output="$result_file" &>/dev/null
}

# --- Execute Benchmarks ----------------------------------------------------
echo "Running disk benchmarks in: $TEST_DIR"
READ_JSON="${TEST_DIR}/fio_read_results.json"
WRITE_JSON="${TEST_DIR}/fio_write_results.json"

# Random Read Test
echo "1/2) Running random read test..."
run_fio_test "randread_test" "randread" "$READ_JSON"
echo "   [Done]"

# Random Write Test
echo "2/2) Running random write test..."
run_fio_test "randwrite_test" "randwrite" "$WRITE_JSON"
echo "   [Done]"

# --- Parse and Display Key Results -----------------------------------------
parse_fio_output() {
  local result_file="$1"
  local mode="$2"

  # If 'jq' is installed, parse JSON. Otherwise, fallback to grep/sed.
  if $JQ_INSTALLED; then
    local iops
    local bw
    local lat50
    local lat99

    iops=$(jq -r '.jobs[0].read.iops + .jobs[0].write.iops' "$result_file")
    bw=$(jq -r '((.jobs[0].read.bw_bytes + .jobs[0].write.bw_bytes)/1048576) | floor' "$result_file")
    lat50=$(jq -r '.jobs[0].clat.percentile."50.000000"' "$result_file")
    lat99=$(jq -r '.jobs[0].clat.percentile."99.000000"' "$result_file")

    echo " - $mode:"
    echo "     IOPS: $iops"
    echo "     BW:   ${bw} MB/s"
    echo "     Latency (p50): ${lat50}us"
    echo "     Latency (p99): ${lat99}us"
  else
    echo " - $mode: (Install 'jq' for detailed parsing)"
    grep -Eo '"iops":[0-9]+|"bw_bytes":[0-9]+' "$result_file" | head -n 4
  fi
}

echo
echo "Benchmark Summary (key metrics):"
parse_fio_output "$READ_JSON" "Random Read"
parse_fio_output "$WRITE_JSON" "Random Write"

# --- Ask if extended info is wanted ----------------------------------------
read -r -p "Would you like to view extended info? (y/N): " SHOW_EXTENDED
if [[ "$SHOW_EXTENDED" =~ ^[Yy]$ ]]; then
  echo "Extended results for Random Read (JSON):"
  cat "$READ_JSON"
  echo
  echo "Extended results for Random Write (JSON):"
  cat "$WRITE_JSON"
fi

# --- Ask if user wants CSV output ------------------------------------------
read -r -p "Would you like to save results to CSV? (y/N): " SAVE_CSV
if [[ "$SAVE_CSV" =~ ^[Yy]$ ]]; then
  CSV_PATH="${TEST_DIR}/fio_results.csv"
  echo "job_name,iops,bw_mb_s,lat50_us,lat99_us" > "$CSV_PATH"

  for json_file in "$READ_JSON" "$WRITE_JSON"; do
    if $JQ_INSTALLED; then
      job_name=$(jq -r '.jobs[0].jobname' "$json_file")
      iops=$(jq -r '.jobs[0].read.iops + .jobs[0].write.iops' "$json_file")
      bw=$(jq -r '((.jobs[0].read.bw_bytes + .jobs[0].write.bw_bytes)/1048576) | floor' "$json_file")
      lat50=$(jq -r '.jobs[0].clat.percentile."50.000000"' "$json_file")
      lat99=$(jq -r '.jobs[0].clat.percentile."99.000000"' "$json_file")
      echo "${job_name},${iops},${bw},${lat50},${lat99}" >> "$CSV_PATH"
    else
      echo "Warning: 'jq' not installed, cannot export extended metrics to CSV."
    fi
  done

  echo "CSV results saved to: $CSV_PATH"
fi

# --- Prompt to remove fio if newly installed -------------------------------
if $FIO_INSTALLED && [[ "$INSTALL_FIO" =~ ^[Yy]$ ]]; then
  echo
  read -r -p "Would you like to remove fio now? (y/N): " REMOVE_FIO
  if [[ "$REMOVE_FIO" =~ ^[Yy]$ ]]; then
    apt-get remove -y fio
    apt-get autoremove -y
    echo "fio removed."
  fi
fi

echo
echo "Disk benchmark process complete."
