#!/bin/bash

# Create output folder named after the hostname
HOSTNAME=$(hostname)
OUTPUT_DIR="${HOSTNAME}_data_$(date +%Y-%m-%d_%H:%M:%S)"

mkdir -p "$OUTPUT_DIR"

    # Function to check if a service is installed and collect its status and logs
check_service() {
    local service_name=$1
    local service_file="${OUTPUT_DIR}/${service_name}.txt"
    echo "Checking service: $service_name" > "$service_file"
    if systemctl list-unit-files | grep -q "$service_name"; then
        echo "$service_name is installed." >> "$service_file"
        echo "Status: " >> "$service_file"
        systemctl is-active "$service_name" >> "$service_file" 2>&1
        echo "---------------------------------......................................" >> "$service_file"
         echo "---------------------------------......................................" >> "$service_file"
        echo "Last 20 lines of $service_name logs:" >> "$service_file"
        journalctl -u "$service_name" | tail -n 20 >> "$service_file" 2>&1
    else
        echo "$service_name is not installed." >> "$service_file"
    fi
}

# Collect disk usage
DISK_USAGE_FILE="${OUTPUT_DIR}/disk_usage.txt"
echo "Disk Usage:" > "$DISK_USAGE_FILE"
df -h >> "$DISK_USAGE_FILE"

# Collect CPU usage
CPU_USAGE_FILE="${OUTPUT_DIR}/cpu_usage.txt"
echo "CPU Usage:" > "$CPU_USAGE_FILE"
top -bn1 | grep "Cpu(s)" >> "$CPU_USAGE_FILE"

# Check services
SERVICES=("named" "isc-dhcp-server" "ssh" "slapd" "apache2" "nfs-server")
for service in "${SERVICES[@]}"; do
    check_service "$service"
done

echo "System information collected in $OUTPUT_DIR"