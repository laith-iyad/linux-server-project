#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/config.sh"


mkdir -p "$DISK_DIR"


setup_disk(){

local img="$1"
local size="$2"
local mnt="$3"

#check if the imgs are exists, so if not make the img 
if [[ ! -f "$img" ]]; then 
       
	echo "Creating img file........." "$img"
	fallocate -l "$size" "$img"
fi

#check if they are formated or not ,,,, 
if ! blkid "$img" &> /dev/null; then
	echo "maiking the file system formate for: " "$img"
	mkfs -t "$FS_TYPE" "$img"   

fi 

#check if the imgs are mounted ,,, if not add them to fstab and will start with the nextreboot 
mkdir -p "$mnt"
if ! awk -v m="$mnt" '$2 == m {found=1} END {exit !found}' /etc/fstab; then
        echo "Adding $mnt to /etc/fstab"
        echo "${img} ${mnt} ${FS_TYPE} ${MNT_OPTS} 0 0" >> /etc/fstab
        systemctl daemon-reload
fi

#to run the mount that we made in the last step now 
if ! mountpoint -q "$mnt"; then
        echo "Mounting $mnt"
        mount "$mnt"
fi
#change the owner to bc the crons will run as the webreport not as the root 
chown "${WEB_USR}:${WEB_USR}" "$mnt"
#change the mod to be used by the webreport only and it's group 
 chmod "$MNT_MODE" "$mnt"
#let the SElinux gives the files the right sticker, so the SElinux does not block it  
restorecon -R "$mnt"

}


setup_disk "$METRICS_IMG" "$METRICS_SIZE" "$METRICS_MNT" 
setup_disk "$BACKUP_IMG"  "$BACKUP_SIZE"  "$BACKUP_MNT"

findmnt --verify

