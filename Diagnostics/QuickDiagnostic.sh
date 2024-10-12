#!/bin/bash

# This script checks for current errors in the Proxmox system, including faults in storage, memory, CPU, networking,
# Ceph, and system logs. It provides a succinct summary to quickly diagnose any issues with the system.
#
# Usage:
# ./CheckSystemErrors.sh

# Function to check storage errors and usage
check_storage_errors() {
    echo "Checking storage errors..."
    zpool_status=$(zpool status 2>/dev/null | grep -i 'FAULTED\|DEGRADED')
    ceph_status=$(ceph health 2>/dev/null | grep -i 'HEALTH_ERR\|HEALTH_WARN')
    storage_usage=$(df -h | awk '$5+0 > 90 {print "Warning: " $6 " is " $5 " full."}')
    locked_storage=$(lvs -o+lock_args 2>/dev/null | grep -i 'lock')

    if [ -n "$zpool_status" ]; then
        echo "Storage errors detected in ZFS:"
        echo "$zpool_status"
    elif [ -n "$ceph_status" ]; then
        echo "Storage errors detected in Ceph:"
        echo "$ceph_status"
    else
        echo "No storage errors found."
    fi

    if [ -n "$storage_usage" ]; then
        echo "Storage usage warning:"
        echo "$storage_usage"
    else
        echo "No storage usage issues found."
    fi

    if [ -n "$locked_storage" ]; then
        echo "Locked storage detected:"
        echo "$locked_storage"
    else
        echo "No locked storage found."
    fi
}

# Function to check memory errors and usage
check_memory_errors() {
    echo "Checking memory errors..."
    memory_errors=$(dmesg | grep -i 'memory error\|out of memory\|oom-killer')
    memory_usage=$(free -m | awk '/Mem:/ {if ($3/$2 * 100 > 90) print "Warning: Memory usage is at " ($3/$2 * 100) "%"}')

    if [ -n "$memory_errors" ]; then
        echo "Memory errors detected:"
        echo "$memory_errors"
    else
        echo "No memory errors found."
    fi

    if [ -n "$memory_usage" ]; then
        echo "Memory usage warning:"
        echo "$memory_usage"
        echo "Processes consuming the most memory:"
        ps -eo pid,ppid,cmd,%mem --sort=-%mem | head -n 5
    else
        echo "No memory usage issues found."
    fi
}

# Function to check CPU errors and usage
check_cpu_errors() {
    echo "Checking CPU errors..."
    cpu_errors=$(dmesg | grep -i 'cpu error\|thermal throttling\|overheating')
    cpu_usage=$(top -bn1 | awk '/^%Cpu/ {if ($2 > 90) print "Warning: CPU usage is at " $2 "%"}')

    if [ -n "$cpu_errors" ]; then
        echo "CPU errors detected:"
        echo "$cpu_errors"
    else
        echo "No CPU errors found."
    fi

    if [ -n "$cpu_usage" ]; then
        echo "CPU usage warning:"
        echo "$cpu_usage"
        echo "Processes consuming the most CPU:"
        ps -eo pid,ppid,cmd,%cpu --sort=-%cpu | head -n 5
    else
        echo "No CPU usage issues found."
    fi
}

# Function to check network errors
check_network_errors() {
    echo "Checking network errors..."
    network_errors=$(dmesg | grep -i 'network error\|link is down\|nic error\|carrier lost')
    if [ -n "$network_errors" ]; then
        echo "Network errors detected:"
        echo "$network_errors"
    else
        echo "No network errors found."
    fi
}

# Function to check system logs for errors
check_system_log_errors() {
    echo "Checking system logs for errors..."
    syslog_errors=$(journalctl -p err -b | grep -i 'error')
    if [ -n "$syslog_errors" ]; then
        echo "Errors detected in system logs:"
        echo "$syslog_errors"
    else
        echo "No errors found in system logs."
    fi
}

# Main script execution
echo "Starting system error check..."

check_storage_errors
check_memory_errors
check_cpu_errors
check_network_errors
check_system_log_errors

echo "System error check completed!"