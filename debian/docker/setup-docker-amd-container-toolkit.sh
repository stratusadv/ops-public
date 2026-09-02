#!/bin/bash

set -e

echo "=== Removing old Docker versions ==="
apt-get remove -y docker docker-engine docker.io containerd runc || true

echo "=== Setting up Docker's official APT repository for Debian ==="
apt-get update
apt-get install -y ca-certificates curl gnupg

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "=== Installing Docker Engine ==="
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "=== Adding current user to the docker group ==="
usermod -aG docker $USER

echo "=== Setting up AMD Container Runtime Toolkit repository ==="
curl -fsSL https://repo.radeon.com/rocm/rocm.gpg.key | gpg --dearmor --yes -o /usr/share/keyrings/amd-container-toolkit-keyring.gpg
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/amd-container-toolkit-keyring.gpg] https://repo.radeon.com/amd-container-toolkit/apt/ noble main" | \
  tee /etc/apt/sources.list.d/amd-container-toolkit.list > /dev/null

echo "=== Installing AMD Container Runtime Toolkit ==="
apt-get update
apt-get install -y amd-container-toolkit

echo "=== Configuring Docker daemon to use AMD runtime ==="
amd-ctk runtime configure

echo "=== Restarting Docker ==="
systemctl restart docker

echo "=== Installation Complete ==="
echo "NOTE: You must log out and log back in for the 'docker' group permissions to take effect."