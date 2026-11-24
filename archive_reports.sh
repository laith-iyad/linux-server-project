#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/config.sh"

REPORTS_COUNT=$(find "$METRICS_MNT" -maxdepth 1 -name 'report_*.json' | wc -l)

if [[ "$REPORTS_COUNT" -eq 0 ]];then
	echo "NO Reports exits"
	exit 0
fi

STAMP=$(date '+%Y-%m-%d_%H%M%S')
ARCHIVE_FILE_NAME="reports_${STAMP}.tar.gz"
ARCHIVE_PATH="${BACKUP_MNT}/${ARCHIVE_FILE_NAME}"

mapfile -t FILES < <(find "$METRICS_MNT" -maxdepth 1 -name 'report_*.json' -printf '%f\n' | sort )

tar -czf "$ARCHIVE_PATH" -C "$METRICS_MNT" "${FILES[@]}"
echo "We Have Created File Named: $ARCHIVE_FILE_NAME with: ${#FILES[@]} reports"


if tar -tzf "$ARCHIVE_PATH" > /dev/null; then 
	for rep in ${FILES[@]}; do 
		rm -f "$METRICS_MNT/$rep"
		rm -f "$METRICS_MNT/$rep"

	done
	echo "Archive OK: deleted ${#FILES[@]} reports from $METRICS_MNT"
	
	else
    		echo "Archive test failed: keeping the reports" >&2
    		rm -f "$ARCHIVE_PATH"
    		exit 1

fi

#--- 4.
(cd "$BACKUP_MNT" && sha256sum "$ARCHIVE_FILE_NAME" > "${ARCHIVE_FILE_NAME}.sha256")
echo "Checksum written: ${ARCHIVE_FILE_NAME}.sha256"

#---5. 


mapfile -t OLD < <(find "$BACKUP_MNT" -maxdepth 1 -name 'reports_*.tar.gz' -printf '%f\n' | sort | head -n -$ARCHIVE_KEEP)

for  old in "${OLD[@]}";do 
	
	    rm -f "$BACKUP_MNT/$old" "$BACKUP_MNT/$old.sha256"
	    echo "Deleted old archive: $old"

done	




