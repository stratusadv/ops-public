#!/bin/bash

echo "Setting up Remote Development"

set -e

apt-get remove -y docker docker-engine docker.io containerd runc || true

apt-get update

apt-get install -y ca-certificates curl gnupg

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt upgrade -y

apt install -y \
    build-essential \
    containerd.io \
    curl \
    docker-buildx-plugin \
    docker-ce \
    docker-ce-cli \
    docker-compose-plugin \
    git \
    micro \
    lazygit \
    libpq-dev \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    wget

wget -qO- https://astral.sh/uv/install.sh | sh

source ~/.bashrc

uv tool install ruff
uv tool install ty
uv tool install python-lsp-server

echo "✅ Done"