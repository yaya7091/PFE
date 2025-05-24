#!/bin/bash

# ===========================
# Linux Supervision Agent (Enhanced)
# ===========================
# Monitors system metrics and key services.
# Outputs a detailed and pretty-printed JSON report with:
# - CPU, disk, RAM usage
# - Per-service status
# - Last N log lines for each service (each line as a distinct JSON string)
# - Detected problems in service logs

# -------- CONFIGURATION --------
SERVICES=("ssh" "apache2" "bind9" "isc-dhcp-server" "slapd")
LOG_DIR="${LOG_DIR:-/var/log/supervision_agent}"
JSON_REPORT="$LOG_DIR/linux_report.json"
LOG_LINES=50 # Number of log lines to collect per service

KEYWORDS="error|fail|critical|unable|denied|panic|segfault"

# -------- SETUP --------
mkdir -p "$LOG_DIR"
chmod 700 "$LOG_DIR"

# -------- FUNCTIONS --------

get_cpu_usage() {
    local idle
    idle=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print $1}')
    local used
    used=$(awk -v idle="$idle" 'BEGIN {print 100 - idle}')
    echo "${used}%"
}

get_disk_usage() {
    df -h / | awk 'NR==2 {print $5}'
}

get_ram_usage() {
    free -h | awk '/Mem:/ {print $3 " / " $2}'
}

json_escape() {
    # Escapes backslashes and double quotes for JSON
    sed 's/\\/\\\\/g; s/"/\\"/g'
}

log_lines_to_json_array() {
    # Reads stdin, outputs a JSON array of lines
    local first=1
    echo -n "["
    while IFS= read -r line; do
        line=$(echo "$line" | json_escape)
        if [ $first -eq 1 ]; then
            echo -n "\"$line\""
            first=0
        else
            echo -n ", \"$line\""
        fi
    done
    echo -n "]"
}

service_json() {
    local name="$1"
    local status="$2"
    local logs_json="$3"
    local problems_json="$4"
    echo "    {
      \"name\": \"$name\",
      \"status\": \"$status\",
      \"logs\": $logs_json,
      \"problems\": $problems_json
    }"
}

collect_service_info() {
    local service="$1"
    local status
    local raw_logs
    local logs_json
    local problems_json

    if systemctl list-unit-files | grep -q "^$service.service"; then
        if systemctl is-active --quiet "$service"; then
            status="active"
        else
            status="inactive"
        fi
        raw_logs=$(journalctl -u "$service" -n "$LOG_LINES" 2>&1)
    else
        status="not installed"
        raw_logs="Service $service is not installed."
    fi

    # Prepare logs as JSON array
    logs_json=$(echo "$raw_logs" | log_lines_to_json_array)

    # Find problem lines (as JSON array)
    problems=$(echo "$raw_logs" | grep -iE "$KEYWORDS" || true)
    problems_json=$(echo "$problems" | log_lines_to_json_array)

    service_json "$service" "$status" "$logs_json" "$problems_json"
}

# -------- MAIN EXECUTION --------

CPU_USAGE=$(get_cpu_usage)
DISK_USAGE=$(get_disk_usage)
RAM_USAGE=$(get_ram_usage)

# Collect all services info as a JSON array
services_json=""
for svc in "${SERVICES[@]}"; do
    svc_json=$(collect_service_info "$svc")
    if [ -n "$services_json" ]; then
        services_json="$services_json,
$svc_json"
    else
        services_json="$svc_json"
    fi
done

# Get all log file names in the log dir (if any)
log_files=$(ls "$LOG_DIR"/*_logs.txt 2>/dev/null | xargs -n1 basename | awk '{printf "\"%s\", ", $1}' | sed 's/, $//')

# Write pretty-printed JSON report
cat > "$JSON_REPORT" <<EOF
{
  "cpu_usage": "$CPU_USAGE",
  "disk_usage": "$DISK_USAGE",
  "ram_usage": "$RAM_USAGE",
  "services": [
$services_json
  ],
  "log_files": [ $log_files ]
}
EOF

# Optionally pretty-print with jq if available
if command -v jq >/dev/null 2>&1; then
    jq . "$JSON_REPORT" > "$JSON_REPORT.tmp" && mv "$JSON_REPORT.tmp" "$JSON_REPORT"
fi

echo "Report generated at $JSON_REPORT"

# -------- CLARIFICATION OF EACH STEP --------
# 1. CONFIGURATION: Set monitored services, log directory, number of log lines, and error keywords.
# 2. SETUP: Ensure a secure log directory.
# 3. FUNCTIONS:
#    - get_cpu_usage / get_disk_usage / get_ram_usage: Gather system metrics.
#    - json_escape: Ensures log lines are safe for JSON.
#    - service_json: Formats a service entry for the JSON report.
#    - collect_service_info: For each service, determines status, collects logs, detects problem lines.
# 4. MAIN EXECUTION:
#    - Gather metrics.
#    - For each service, collect info and build a JSON array.
#    - Write a pretty-printed JSON report, optionally using jq for formatting.