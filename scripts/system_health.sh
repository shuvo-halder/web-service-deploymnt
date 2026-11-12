#!/bin/bash

set -euo pipefail

LOG_FILE="health_log.txt"
MAX_LOG_SIZE=$((10 * 1024 * 1024)) # 10 MB for log rotation
OUTPUT_JSON=0

THRESH_CPU=90
THRESH_MEM=85
THRESH_DISK=80

usage() {
    cat << EOF
Usage: $0 [OPTIONS]
Monitor system health and log metrics.

Options:
  --cpu <num>     Set CPU alert threshold % (default: 90)
  --mem <num>     Set Memory alert threshold % (default: 85)
  --disk <num>    Set Disk alert threshold % (default: 80)
  --json          Output log in JSON format
  -h, --help      Show this help message
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --cpu) THRESH_CPU="$2"; shift 2 ;;
        --mem) THRESH_MEM="$2"; shift 2 ;;
        --disk) THRESH_DISK="$2"; shift 2 ;;
        --json) OUTPUT_JSON=1; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}' | awk '{printf "%.0f", $1}')
MEM_USAGE=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100)}')
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | xargs)
TOP_PROCS=$(ps -eo pid,cmd,%mem,%cpu --sort=-%mem | head -n 6 | tail -n 5 | tr '\n' ';' | sed 's/;/ | /g')

EXIT_CODE=0
WARNINGS=""

if [ "$CPU_USAGE" -ge "$THRESH_CPU" ]; then
    WARNINGS+="[WARNING] CPU usage is at ${CPU_USAGE}%. "
    EXIT_CODE=1
fi

if [ "$MEM_USAGE" -ge "$THRESH_MEM" ]; then
    WARNINGS+="[WARNING] Memory usage is at ${MEM_USAGE}%. "
    EXIT_CODE=1
fi

DISK_WARNINGS=$(df -h | awk 'NR>1 && $1 ~ /^\/dev\// {print $5, $6}' | while read -r pcent mount; do
    p=${pcent%\%}
    if [ "$p" -ge "$THRESH_DISK" ]; then
        echo "[WARNING] Disk usage on $mount is at ${pcent}. "
    fi
done)

if [ -n "$DISK_WARNINGS" ]; then
    WARNINGS+="$DISK_WARNINGS"
    EXIT_CODE=1
fi

if [ "$CPU_USAGE" -ge 99 ] || [ "$MEM_USAGE" -ge 99 ]; then
    EXIT_CODE=2
fi

if [ -f "$LOG_FILE" ]; then
    FILE_SIZE=$(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE")
    if [ "$FILE_SIZE" -ge "$MAX_LOG_SIZE" ]; then
        mv "$LOG_FILE" "${LOG_FILE}.old"
    fi
fi

if [ $OUTPUT_JSON -eq 1 ]; then
    LOG_ENTRY="{\"timestamp\":\"$TIMESTAMP\",\"cpu_percent\":$CPU_USAGE,\"mem_percent\":$MEM_USAGE,\"load_avg\":\"$LOAD_AVG\",\"top_procs\":\"$TOP_PROCS\",\"warnings\":\"$WARNINGS\"}"
else
    LOG_ENTRY="[$TIMESTAMP] CPU: ${CPU_USAGE}% | MEM: ${MEM_USAGE}% | LOAD: $LOAD_AVG | PROCS: $TOP_PROCS"
    if [ -n "$WARNINGS" ]; then
        LOG_ENTRY="$LOG_ENTRY | ALERTS: $WARNINGS"
    fi
fi

echo "$LOG_ENTRY" >> "$LOG_FILE"

if [ -n "$WARNINGS" ]; then
    echo "$WARNINGS" >&2
fi

exit $EXIT_CODE