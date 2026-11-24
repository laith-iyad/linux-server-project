#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh

# --- must run as root ---
if [[ "$EUID" -ne 0 ]]; then
    echo "Please run as root: sudo ./run.sh" >&2
    exit 1
fi

# --- send everything to the screen AND install.log ---
mkdir -p "$LOG_DIR"
exec > >(tee -a "$INSTALL_LOG") 2>&1

STEPS=(
    setup_private_repo.sh
    install_apache.sh
    configure_https.sh
    mount_disks.sh
    setup_crons.sh
    verify.sh
)

echo "===== run.sh started: $(date '+%Y-%m-%d %H:%M:%S') ====="

for step in "${STEPS[@]}"; do
    echo
    echo "----- $step -----"
    if ! bash "./$step"; then
        echo "ERROR: $step failed. Full log: $INSTALL_LOG" >&2
        exit 1
    fi
done

echo
echo "===== run.sh finished OK: $(date '+%Y-%m-%d %H:%M:%S') ====="
