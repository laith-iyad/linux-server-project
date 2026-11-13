#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/config.sh"
dnf install -y httpd

if ! id "$WEB_USR" &> /dev/null; then 

      useradd -rM -s "/sbin/nologin" "$WEB_USR"
fi

sed -i "s/User apache/User $WEB_USR/" $HTTPD_CONF
sed -i "s/Group apache/Group $WEB_USR/" $HTTPD_CONF

touch  "$APACHE_FOLDER/index.html"
echo "Z $APACHE_FOLDER - $WEB_USR $WEB_USR -" > "$APACHE_OWNER_CONF/apache_owner.conf"
chown -R "$WEB_USR:$WEB_USR" "$APACHE_FOLDER"

apachectl configtest
systemctl enable httpd && systemctl start httpd
