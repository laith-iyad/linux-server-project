#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/config.sh"

HOST="$(hostname)"
IP="$(hostname -i|awk '{print $2}')"
OS=$(cat /etc/os-release | grep "PRETTY_NAME" | cut -d'=' -f2 | cut -d'"' -f2)
KERNAL=$(uname -r) 
UPTIME=$(uptime -p)
LOAD=$(cut -d' ' -f1-3 "/proc/loadavg") #load of the CPU : last 1mins, last 5mins, last 15mins

CPU=$(vmstat 1 2 | tail -n 1 | awk  '{print 100 - $15}')
MEM=$(free | awk '/^Mem:/ {printf "%.0f", $3 / $2 *100 }')
#MEM=$(free | awk '/^Mem:/ {printf "%.0f", $3 / $2 * 100}')

disk_size_used(){
df "$1" | tail -n 1 | awk '{print $5}' | tr -d '%'
}


DISK_ROOT=$(disk_size_used /)
DISK_METRICS=$(disk_size_used "$METRICS_MNT")
DISK_BACKUP=$(disk_size_used "$BACKUP_MNT")
USERS=$(who | awk '{print $1}' | sort -u | wc -l)

PORTS=$(ss -tlnH | awk '{print $4}' | awk -F: '{print $NF}' | sort -un | paste -sd',')
TOP_PROCS=$(ps -eo comm,%mem --sort=-%mem --no-headers \
    | awk 'NR<=5 {print $1 " (" $2 "%)"}' | paste -sd ',')

srv_state(){
systemctl is-active "$1" || true 
}


HTTP_STATE=$(srv_state httpd)
CRON_STATE=$(srv_state crond)
FIREWALL_STATE=$(srv_state firewalld)
ARCHIVE_FILE=$(find "$BACKUP_MNT" -maxdepth 1 -name 'reports_*.tar.gz' | wc -l )
NEWST_ARCHIVE=$(find "$BACKUP_MNT" -maxdepth 1 -name 'reports_*.tar.gz' -printf '%f\n' |sort | tail -n 1 )
NEWST_ARCHIVE=${NEWST_ARCHIVE:-none}

NOW_EPOCH=$(date +%s)
NOW_HUMAN=$(date '+%Y-%m-%d %H:%M:%S')

# --- JSON report ---
jq -n \
    --arg time "$NOW_HUMAN" \
    --arg hostname "$HOST" \
    --arg ip "$IP" \
    --arg os "$OS" \
    --arg kernel "$KERNAL" \
    --arg uptime "$UPTIME" \
    --arg load "$LOAD" \
    --argjson cpu "$CPU" \
    --argjson mem "$MEM" \
    --argjson disk_root "$DISK_ROOT" \
    --argjson disk_metrics "$DISK_METRICS" \
    --argjson disk_backup "$DISK_BACKUP" \
    --argjson users "$USERS" \
    --arg ports "$PORTS" \
    --arg top "$TOP_PROCS" \
    --arg httpd "$HTTP_STATE" \
    --arg crond "$CRON_STATE" \
    --arg firewalld "$FIREWALL_STATE" \
    --argjson archives "$ARCHIVE_FILE" \
    --arg newest "$NEWST_ARCHIVE" \
    '{
        time: $time, hostname: $hostname, ip: $ip, os: $os,
        kernel: $kernel, uptime: $uptime, load_average: $load,
        cpu_percent: $cpu, memory_percent: $mem,
        disk_percent: { root: $disk_root, metrics: $disk_metrics, backup: $disk_backup },
        logged_in_users: $users,
        listening_ports: ($ports | split(",") | map(tonumber)),
        top_processes: ($top | split(",")),
        services: { httpd: $httpd, crond: $crond, firewalld: $firewalld },
        archives: { count: $archives, newest: $newest }
    }' > "${METRICS_MNT}/report_${NOW_EPOCH}.json"


# --- HTML page ---
TOP_HTML=$(echo "$TOP_PROCS" | tr ',' '\n' | sed 's|.*|<li>&</li>|')
TMP_PAGE="${INDEX_FILE}.tmp"

cat > "$TMP_PAGE" << EOF
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta http-equiv="refresh" content="${REFRESH_SEC}">
<title>${HOST} status</title>
<style>
  body { font-family: sans-serif; margin: 2em; }
  td   { padding: 4px 12px; border-bottom: 1px solid #ddd; }
</style>
</head>
<body>
<h1>${HOST} status</h1>
<p>Generated: ${NOW_HUMAN}</p>

<h2>System</h2>
<table>
<tr><td>IP address</td><td>${IP}</td></tr>
<tr><td>OS</td><td>${OS}</td></tr>
<tr><td>Kernel</td><td>${KERNAL}</td></tr>
<tr><td>Uptime</td><td>${UPTIME}</td></tr>
<tr><td>Load average (1, 5, 15 min)</td><td>${LOAD}</td></tr>
</table>

<h2>Usage</h2>
<table>
<tr><td>CPU</td><td>${CPU}%</td></tr>
<tr><td>Memory</td><td>${MEM}%</td></tr>
<tr><td>Disk /</td><td>${DISK_ROOT}%</td></tr>
<tr><td>Disk ${METRICS_MNT}</td><td>${DISK_METRICS}%</td></tr>
<tr><td>Disk ${BACKUP_MNT}</td><td>${DISK_BACKUP}%</td></tr>
</table>

<h2>Users and network</h2>
<table>
<tr><td>Logged-in users</td><td>${USERS}</td></tr>
<tr><td>Listening TCP ports</td><td>${PORTS}</td></tr>
</table>

<h2>Top 5 processes (memory)</h2>
<ol>
${TOP_HTML}
</ol>

<h2>Services</h2>
<table>
<tr><td>httpd</td><td>${HTTP_STATE}</td></tr>
<tr><td>crond</td><td>${CRON_STATE}</td></tr>
<tr><td>firewalld</td><td>${FIREWALL_STATE}</td></tr>
</table>

<h2>Archives</h2>
<table>
<tr><td>Number of archives</td><td>${ARCHIVE_FILE}</td></tr>
<tr><td>Newest archive</td><td>${NEWST_ARCHIVE}</td></tr>
</table>

<p><a href="/repo/">Private package repository</a></p>
</body>
</html>
EOF

mv -f "$TMP_PAGE" "$INDEX_FILE"
