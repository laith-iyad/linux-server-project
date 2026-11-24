#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="linux-server-project"
LOG_DIR="/var/log/${PROJECT_NAME}"
INSTALL_LOG="${LOG_DIR}/install.log"

PACKAGES=(httpd mod_ssl jq cronie logrotate)
REPORT_PACKAGES=(jq cronie logrotate)

REPO_ID="private-local"
REPO_DIR="/var/www/repo"
PRIVATE_REPO_DIR="${REPO_DIR}/Packages"
DNF_REPOS="/etc/yum.repos.d"
REPO_FILE="${DNF_REPOS}/${REPO_ID}.repo"

#GPG_KEY=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-9

# signing key of this distribution (Red Hat family only)
OS_ID=$(. /etc/os-release && echo "$ID")
case "$OS_ID" in
    rocky)     GPG_KEY="file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-9" ;;
    almalinux) GPG_KEY="file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-9" ;;
    rhel)      GPG_KEY="file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release" ;;
    *)         echo "Unsupported OS: $OS_ID (Rocky, AlmaLinux or RHEL 9 only)" >&2; exit 1 ;;
esac

STATE_DIR="/var/lib/${PROJECT_NAME}"
OFFICIAL_REPOS_FILE="${STATE_DIR}/official-repos.list"



WEB_USR="webreport"
HTTPD_CONF="/etc/httpd/conf/httpd.conf"
APACHE_FOLDER="/var/www/html"
APACHE_OWNER_CONF="/etc/tmpfiles.d/apache_owner.conf"
RSA_BITS=2048
VALID_DAYS=365
RENEW_DAYS=30 #if the cert expires in 30 days then make a new one
KEY_FILE="/etc/pki/tls/private/apache.key"
CERT_FILE="/etc/pki/tls/certs/apache.crt"
MOD=600
TRS_CERT_DIR="/etc/pki/ca-trust/source/anchors/"

SITE_CONF="/etc/httpd/conf.d/${PROJECT_NAME}.conf"
SITE_ERROR_LOG="/var/log/httpd/${PROJECT_NAME}_error.log"
SITE_ACCESS_LOG="/var/log/httpd/${PROJECT_NAME}_access.log"

WEB_ROOT="/var/www"
FW_SERVICES=(https http)

DISK_DIR="/var/lib/${PROJECT_NAME}"
FS_TYPE="xfs"
MNT_MODE=750

METRICS_IMG="${DISK_DIR}/metrics.img"
METRICS_SIZE="512M"
METRICS_MNT="/mnt/metrics"

BACKUP_IMG="${DISK_DIR}/backup.img"
BACKUP_SIZE="1G"
BACKUP_MNT="/backup"

MNT_OPTS="defaults,loop,nofail"

INDEX_FILE="${APACHE_FOLDER}/index.html"
REFRESH_SEC=60
ARCHIVE_KEEP=48

INSTALL_DIR="/opt/$PROJECT_NAME"

CRON_LOG="$LOG_DIR/cron.log"
CRON_FILE="/etc/cron.d/${PROJECT_NAME}"
REPORT_SCHEDULE="* * * * *"
ARCHIVE_SCHEDULE="*/10 * * * *"

LOGROTATE_FILE="/etc/logrotate.d/${PROJECT_NAME}"
LOG_KEEP=7

PAGE_MAX_AGE_MIN=3

print_fun(){
echo $1
}


