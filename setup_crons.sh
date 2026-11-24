#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/config.sh"

SRC_FILE="$(dirname "$0")"

dnf install -y "${REPORT_PACKAGES[@]}"
systemctl enable --now crond

mkdir -p -m 755 "$INSTALL_DIR"
cp "$SRC_FILE/archive_reports.sh" "$SRC_FILE/generate_report.sh" "$INSTALL_DIR/"
chmod 755 "$INSTALL_DIR/archive_reports.sh" "$INSTALL_DIR/generate_report.sh"

install -m 644 "$SRC_FILE/config.sh" "$INSTALL_DIR/" 

mkdir -p "$LOG_DIR"
touch "$CRON_LOG"
chown "${WEB_USR}:${WEB_USR}" "$CRON_LOG"
chmod 640 "$CRON_LOG"



# --- 4. cron file ---
cat > "$CRON_FILE" << EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

${REPORT_SCHEDULE}  ${WEB_USR}  ${INSTALL_DIR}/generate_report.sh >> ${CRON_LOG} 2>&1
${ARCHIVE_SCHEDULE}  ${WEB_USR}  ${INSTALL_DIR}/archive_reports.sh >> ${CRON_LOG} 2>&1
EOF
chmod 644 "$CRON_FILE"


# --- 5. logrotate for cron.log ---
cat > "$LOGROTATE_FILE" << EOF
${CRON_LOG} {
    daily
    rotate ${LOG_KEEP}
    compress
    missingok
    notifempty
    create 0640 ${WEB_USR} ${WEB_USR}
}
EOF
chmod 644 "$LOGROTATE_FILE"

# --- 6. first run: report -> archive -> report ---
runuser -u "$WEB_USR" -- "$INSTALL_DIR/generate_report.sh"
runuser -u "$WEB_USR" -- "$INSTALL_DIR/archive_reports.sh"
runuser -u "$WEB_USR" -- "$INSTALL_DIR/generate_report.sh"


