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

