#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="linux-server-project"
LOG_DIR="/var/log/${PROJECT_NAME}"
INSTALL_LOG="${LOG_DIR}/install.log"

PACKAGES=(httpd mod_ssl)
REPO_ID="private-local"
REPO_DIR="/var/www/repo"
PRIVATE_REPO_DIR="${REPO_DIR}/Packages"
DNF_REPOS="/etc/yum.repos.d"
REPO_FILE="${DNF_REPOS}/${REPO_ID}.repo"

GPG_KEY=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-9
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


print_fun(){
echo $1
}


