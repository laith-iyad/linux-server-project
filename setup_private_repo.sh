#!/usr/bin/env bash
set -euo pipefail
source  "$(dirname "$0")/config.sh"

mkdir -p "$PRIVATE_REPO_DIR" 

dnf download --resolve --alldeps --destdir="$PRIVATE_REPO_DIR" "${PACKAGES[@]}" --disablerepo="$REPO_ID"


dnf install -y createrepo_c --disablerepo="$REPO_ID"

createrepo_c  --update "$REPO_DIR"

cat > "${REPO_FILE}" << EOF
[$REPO_ID]
name=local-private
baseurl=file://${REPO_DIR}
enabled=1
gpgcheck=1
gpgkey=${GPG_KEY}
EOF
