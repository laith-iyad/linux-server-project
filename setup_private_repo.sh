#!/usr/bin/env bash
set -euo pipefail
source  "$(dirname "$0")/config.sh"

mkdir -p "$STATE_DIR"
if [[ ! -s "$OFFICIAL_REPOS_FILE" ]]; then
    dnf repolist --enabled -q \
        | awk -v me="$REPO_ID" '$1 != "repo" && $1 != me {print $1}' > "$OFFICIAL_REPOS_FILE"
fi
mapfile -t OFFICIAL_REPOS < "$OFFICIAL_REPOS_FILE"

SRC_OPTS=(--disablerepo='*')
for repo in "${OFFICIAL_REPOS[@]}"; do
    SRC_OPTS+=(--enablerepo="$repo")
done




mkdir -p "$PRIVATE_REPO_DIR" 
print_fun "download Packages into the Packages Folder:"
#dnf download --resolve --alldeps --destdir="$PRIVATE_REPO_DIR" "${PACKAGES[@]}" --disablerepo="$REPO_ID"

dnf download "${SRC_OPTS[@]}" --resolve --alldeps --destdir="$PRIVATE_REPO_DIR" "${PACKAGES[@]}"
dnf install -y "${SRC_OPTS[@]}" createrepo_c dnf-plugins-core

#dnf install -y createrepo_c --disablerepo="$REPO_ID"

createrepo_c  --update "$REPO_DIR"
restorecon -v "${WEB_ROOT}"
restorecon -Rv "${REPO_DIR}"

cat > "${REPO_FILE}" << EOF
[$REPO_ID]
name=local-private
baseurl=file://${REPO_DIR}
enabled=1
gpgcheck=1
gpgkey=${GPG_KEY}
EOF

if [[ "${#OFFICIAL_REPOS[@]}" -gt 0 ]]; then
    dnf config-manager --set-disabled "${OFFICIAL_REPOS[@]}"
fi


