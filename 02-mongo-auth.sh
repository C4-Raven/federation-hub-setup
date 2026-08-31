#!/bin/bash
# Step 2: lock down MongoDB with auth (starts open, creates the fed hub's DB
# user with a generated password, then flips authorization on).
# Requires 01-base-install.sh to have completed. Run: bash 02-mongo-auth.sh
set -euxo pipefail

# The package's own script: writes/reads dbUsername+dbPassword in
# federation-hub-broker.yml, creates that mongo user, then switches
# /etc/mongod.conf from mongod-noauth.conf to mongod-auth.conf.
sudo /opt/tak/federation-hub/scripts/db/configure.sh

echo
echo "=== Mongo auth configured. Credentials (also live in federation-hub-broker.yml): ==="
sudo grep -E "dbUsername|dbPassword" /opt/tak/federation-hub/configs/federation-hub-broker.yml

echo
echo "=== Verifying mongod is up with auth enabled ==="
sleep 2
sudo systemctl status mongod --no-pager || true
echo "Next: bash 03-generate-certs.sh"
