#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/config.sh"
dnf install -y --repo="$REPO_ID" mod_ssl
systemctl restart httpd
systemctl enable --now firewalld

IP=$(hostname -i | awk '{print $2}')
HOST=$(hostname)

if [[ ! -f "$CERT_FILE" || ! -f "$KEY_FILE" ]] \
   || ! openssl x509 -checkend $(( RENEW_DAYS * 86400 )) -noout -in "$CERT_FILE" \
   || ! openssl x509 -noout -ext subjectAltName -in "$CERT_FILE" | grep -q "IP Address:${IP}"; then

        openssl req -x509 \
	-newkey rsa:"$RSA_BITS" \
	-noenc \
	-keyout "${KEY_FILE}" \
	-out "${CERT_FILE}" \
	-days "$VALID_DAYS" \
	-subj "/CN=${HOST}" \
	-addext "subjectAltName=DNS:${HOST},IP:${IP}"

        chmod "$MOD" "$KEY_FILE"

        cp "$CERT_FILE" "$TRS_CERT_DIR"
        update-ca-trust

fi
   

cat > "$SITE_CONF" << EOF  
    
    ServerName ${HOST}
    ServerTokens Prod
    ServerSignature Off

<Directory ${APACHE_FOLDER}>
    Options -Indexes

</Directory>

<VirtualHost *:80>
    ServerName ${HOST}
    Redirect permanent / https://${HOST}/
</VirtualHost>


<VirtualHost *:443>
    ServerName ${HOST}
    DocumentRoot ${APACHE_FOLDER}

    SSLEngine on
    SSLCertificateFile ${CERT_FILE}
    SSLCertificateKeyFile ${KEY_FILE}

    Alias /repo ${REPO_DIR}

    <Directory ${REPO_DIR}>
        Options +Indexes
        Require all granted
    </Directory>

    ErrorLog ${SITE_ERROR_LOG}
    CustomLog ${SITE_ACCESS_LOG} combined
</VirtualHost>

EOF

apachectl configtest
systemctl reload-or-restart httpd


for svc in "${FW_SERVICES[@]}"; do 

	if ! firewall-cmd --permanent --quiet --query-service=$svc; then
           firewall-cmd --permanent --add-service=$svc	   
    fi
done

firewall-cmd --reload







