#!/bin/bash

# Define services to monitor
SERVICES=("ssh" "apache2" "bind9" "isc-dhcp-server" "slapd")  # Adjust names for your system
LOG_DIR="/tmp/service_logs"  # Directory to store logs
mkdir -p "$LOG_DIR"

# 1. CPU, Disk, RAM (General metrics)
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')
RAM_USAGE=$(free -h | awk '/Mem:/ {print $3 " / " $2}')

# 2. Check each service and save logs
SERVICE_STATUS=()
for service in "${SERVICES[@]}"; do
    STATUS_FILE="$LOG_DIR/${service}_status.txt"
    LOG_FILE="$LOG_DIR/${service}_logs.txt"

    # Check if service exists
    if systemctl list-unit-files | grep -q "^$service.service"; then
        # Get service status (Running/Not Running)
        if systemctl is-active --quiet "$service"; then
            STATUS="active"
        else
            STATUS="inactive"
        fi

        # Get last 10 lines of logs (adjust command per service)
        case "$service" in
            "ssh")       JOURNALCTL_CMD="journalctl -u ssh -n 10" ;;
            "apache2")    JOURNALCTL_CMD="journalctl -u apache2 -n 10" ;;
            "bind9")      JOURNALCTL_CMD="journalctl -u bind9 -n 10" ;;
            "isc-dhcp-server") JOURNALCTL_CMD="journalctl -u isc-dhcp-server -n 10" ;;
            "slapd")      JOURNALCTL_CMD="journalctl -u slapd -n 10" ;;
            *)            JOURNALCTL_CMD="echo 'No log command defined'" ;;
        esac

        # Save status and logs
        echo "$STATUS" > "$STATUS_FILE"
        eval "$JOURNALCTL_CMD" > "$LOG_FILE" 2>&1
    else
        echo "Not Installed" > "$STATUS_FILE"
        echo "Service $service is not installed." > "$LOG_FILE"
    fi

    SERVICE_STATUS+=("$service: $(cat "$STATUS_FILE")")
done

# 3. Save all data to a JSON file (for DeepSeek API)
JSON_REPORT="$LOG_DIR/linux_report.json"
echo "{
  \"cpu_usage\": \"$CPU_USAGE\",
  \"disk_usage\": \"$DISK_USAGE\",
  \"ram_usage\": \"$RAM_USAGE\",
  \"services\": \"$(printf '%s, ' "${SERVICE_STATUS[@]}" | sed 's/, $//')\",
  \"log_files\": [\"$(ls $LOG_DIR/*_logs.txt | sed ':a;N;$!ba;s/\n/", "/g')\"]
}" > "$JSON_REPORT"

echo "Report generated: $JSON_REPORT"