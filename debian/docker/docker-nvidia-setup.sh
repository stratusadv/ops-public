#!/bin/bash

set -e

echo "=== Removing old Docker versions ==="
sudo apt-get remove -y docker docker-engine docker.io containerd runc || true

echo "=== Setting up Docker's official APT repository for Debian ==="
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources (using debian instead of ubuntu)
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "=== Installing Docker Engine ==="
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "=== Adding current user to the docker group ==="
sudo usermod -aG docker $USER

echo "=== Setting up NVIDIA Container Toolkit repository ==="
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

echo "=== Installing NVIDIA Container Toolkit ==="
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

echo "=== Configuring Docker daemon to use NVIDIA runtime ==="
sudo nvidia-ctk runtime configure --runtime=docker

echo "=== Restarting Docker ==="
sudo systemctl restart docker

echo "=== Installation Complete ==="
echo "NOTE: You must log out and log back in for the 'docker' group permissions to take effect."