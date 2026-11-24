#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/config.sh"

HOST=$(hostname)
IP=$(hostname -i | awk '{print $2}')
FAILS=0

# --- the PASS / FAIL helper ---
check() {
    local desc="$1"
    shift
    if "$@" &>/dev/null; then
        echo "PASS  $desc"
    else
        echo "FAIL  $desc"
        FAILS=$((FAILS + 1))
    fi
}

# --- small test functions ---
only_private_repo() {
    [[ "$(dnf repolist --enabled -q | awk '$1 != "repo" {print $1}')" == "$REPO_ID" ]]
}
httpd_from_private() {
    dnf list --installed httpd -q | grep -qw "@${REPO_ID}"
}
svc_ok() {
    systemctl is-enabled -q "$1" && systemctl is-active -q "$1"
}
workers_user() {
    [[ "$(ps -o user= -C httpd | awk '$1 != "root" {print $1}' | sort -u)" == "$WEB_USR" ]]
}
http_code_is() {
    [[ "$(curl -s -o /dev/null -w '%{http_code}' "$1")" == "$2" ]]
}
in_fstab() {
    awk -v m="$1" '$2 == m {found=1} END {exit !found}' /etc/fstab
}
page_fresh() {
    [[ -n "$(find "$INDEX_FILE" -mmin -"$PAGE_MAX_AGE_MIN")" ]]
}
archive_ok() {
    local newest
    newest=$(find "$BACKUP_MNT" -maxdepth 1 -name 'reports_*.tar.gz' -printf '%f\n' | sort | tail -n 1)
    [[ -n "$newest" ]] && (cd "$BACKUP_MNT" && sha256sum -c --quiet "${newest}.sha256")
}

# --- the checks ---
check "only $REPO_ID is enabled"                 only_private_repo
check "httpd installed from $REPO_ID"            httpd_from_private

for svc in httpd firewalld crond; do
    check "$svc enabled and running"             svc_ok "$svc"
done

check "Apache workers run as $WEB_USR"           workers_user
check "https://$HOST/ returns 200 (no -k)"       http_code_is "https://$HOST/" 200
check "http://$HOST/ returns 301"                http_code_is "http://$HOST/" 301
check "/repo/repodata/repomd.xml returns 200"    http_code_is "https://$HOST/repo/repodata/repomd.xml" 200

for mnt in "$METRICS_MNT" "$BACKUP_MNT"; do
    check "$mnt is mounted"                      mountpoint -q "$mnt"
    check "$mnt is in /etc/fstab"                in_fstab "$mnt"
done
check "/etc/fstab passes findmnt --verify"       findmnt --verify

check "index.html updated in the last ${PAGE_MAX_AGE_MIN} min"  page_fresh
check "newest archive exists and checksum matches"              archive_ok
check "SELinux is Enforcing"                     test "$(getenforce)" = "Enforcing"

# --- result ---
if [[ "$FAILS" -gt 0 ]]; then
    echo "$FAILS check(s) failed" >&2
    exit 1
fi
echo "Site ready: https://${IP}/"
