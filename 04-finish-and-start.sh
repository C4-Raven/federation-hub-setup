#!/bin/bash
# Step 4: point the fed hub's configs at the certs from step 3, register the
# systemd service (the .deb's postinst only does this on RHEL/Rocky -- this
# host is Ubuntu, so it never happened), authorize the admin cert, and start.
# Requires 02-mongo-auth.sh and 03-generate-certs.sh to have completed.
# Run: bash 04-finish-and-start.sh
set -euxo pipefail

CFG=/opt/tak/federation-hub/configs
CERTS=/opt/tak/federation-hub/certs/files

source <(sudo cat /opt/tak/federation-hub/certs/.fedhub-cert-passwords)

# --- broker config: server keystore + fed truststore ---
sudo sed -i \
  -e "s#^keystoreFile:.*#keystoreFile: ${CERTS}/tak.c4raven.net.jks#" \
  -e "s#^keystorePassword:.*#keystorePassword: ${PASS}#" \
  -e "s#^truststoreFile:.*#truststoreFile: ${CERTS}/fed-truststore.jks#" \
  -e "s#^truststorePassword:.*#truststorePassword: ${CAPASS}#" \
  -e "s#^caFile:.*#caFile: ${CERTS}/ca.pem#" \
  "$CFG/federation-hub-broker.yml"

# --- UI config: server keystore + root truststore + correct key alias ---
sudo sed -i \
  -e "s#^keystoreFile:.*#keystoreFile: ${CERTS}/tak.c4raven.net.jks#" \
  -e "s#^keystorePassword:.*#keystorePassword: ${PASS}#" \
  -e "s#^truststoreFile:.*#truststoreFile: ${CERTS}/truststore-root.jks#" \
  -e "s#^truststorePassword:.*#truststorePassword: ${CAPASS}#" \
  -e "s#^keyAlias:.*#keyAlias: tak.c4raven.net#" \
  "$CFG/federation-hub-ui.yml"

sudo chown tak:tak "$CFG"/federation-hub-broker.yml "$CFG"/federation-hub-ui.yml

# --- register the systemd unit (skipped by postinst on non-RHEL) ---
# Supervised: bash waits for the FIRST of the four parts to exit (wait -n) and
# then fails, so systemd stops the other three and restarts all four. A plain
# `wait` with RemainAfterExit=yes left a dead or killed hub down for good.
sudo bash -c 'cat > /etc/systemd/system/federation-hub.service <<EOF
[Unit]
Description=Federation Hub Service
After=network.target mongod.service
Requires=mongod.service

[Service]
Type=simple
WorkingDirectory=/opt/tak/federation-hub/scripts
ExecStart=/bin/bash -c "./federation-hub-policy.sh & ./federation-hub-plugin-manager.sh & ./federation-hub-ui.sh & ./federation-hub-broker.sh & wait -n; exit 1"
Restart=on-failure
RestartSec=10s
User=tak
Group=tak
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF'
sudo systemctl daemon-reload

# --- authorize the admin client cert for the UI ---
sudo -u tak java -jar /opt/tak/federation-hub/jars/federation-hub-manager.jar "${CERTS}/fedhub-admin.pem"

# --- start it ---
sudo systemctl enable --now federation-hub
sleep 8
sudo systemctl status federation-hub --no-pager || true

echo
echo "=== Listening ports (expect 9100 UI, 9101 fed-v1, 9102 fed-v2) ==="
ss -tlnp | grep -E ':(9100|9101|9102)\b' || echo "not up yet -- check: sudo journalctl -u federation-hub -n 100 --no-pager"

echo
echo "Admin UI: https://tak.c4raven.net:9100  (browser must present the fedhub-admin.p12 client cert)"
