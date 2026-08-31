#!/bin/bash
# Step 1: MongoDB 7.0 + openjdk-17-jdk + the Federation Hub .deb itself.
# Run in a real terminal (sudo needs a real TTY): bash 01-base-install.sh
set -euxo pipefail

DEB_PATH="/home/tak/Downloads/Federation hub docs and deb/takserver-fed-hub_5.8-RELEASE75_all.deb"

# --- MongoDB 7.0 official repo (using jammy packages -- MongoDB doesn't yet publish
#     for Ubuntu 25.10 "questing", but jammy's .debs run fine on newer Ubuntu). ---
sudo apt-get update -y
sudo apt-get install -y curl gnupg software-properties-common apt-transport-https ca-certificates

curl -fsSL https://pgp.mongodb.com/server-7.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor --yes
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

sudo apt-get update -y
sudo apt-get install -y mongodb-org mongodb-mongosh openjdk-17-jdk

sudo systemctl enable mongod
sudo systemctl start mongod
sleep 3
sudo systemctl status mongod --no-pager || true

# --- Federation Hub .deb itself ---
sudo apt-get install -y "$DEB_PATH"

echo
echo "=== Base install complete. Verify: ==="
mongod --version | head -1
java -version
dpkg -l | grep takserver-fed-hub
echo "Next: bash 02-mongo-auth.sh"
