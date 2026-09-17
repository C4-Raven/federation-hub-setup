#!/bin/bash
# Step 3: generate a DEDICATED Federation Hub CA (kept separate from your
# Raven/EUD CA at /home/tak/ots/ca, per your earlier decision), plus
# a server cert (tak.c4raven.net) and one admin client cert (fedhub-admin).
# Requires 01-base-install.sh to have completed. Run: bash 03-generate-certs.sh
set -euo pipefail

CAPASS=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)
PASS=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)

# Save the passwords root/tak-only -- 04-finish-and-start.sh reads these back
# to wire the keystore/truststore passwords into the fed hub's config files.
sudo bash -c "umask 077; printf 'CAPASS=%s\nPASS=%s\n' '$CAPASS' '$PASS' > /opt/tak/federation-hub/certs/.fedhub-cert-passwords; chown tak:tak /opt/tak/federation-hub/certs/.fedhub-cert-passwords"

sudo -u tak bash -c "
set -euxo pipefail
cd /opt/tak/federation-hub/certs
export COUNTRY=WW STATE=XX CITY=YY ORGANIZATION=ZZ ORGANIZATIONAL_UNIT=C4Raven-FedHub
export CAPASS='$CAPASS' PASS='$PASS'
./makeRootCa.sh --ca-name C4Raven-FedHub-CA
./makeCert.sh server tak.c4raven.net
./makeCert.sh client fedhub-admin
"

echo
echo "=== Certs generated under /opt/tak/federation-hub/certs/files/ ==="
sudo -u tak ls -la /opt/tak/federation-hub/certs/files/
echo
echo "IMPORTANT: fedhub-admin.p12 is your browser login cert for the Federation"
echo "Hub's native admin UI (https://tak.c4raven.net:9100). Copy it off this"
echo "server securely (scp/USB) -- it contains a private key. Its import"
echo "password is the PASS value saved in /opt/tak/federation-hub/certs/.fedhub-cert-passwords"
echo
echo "Next: bash 04-finish-and-start.sh"
