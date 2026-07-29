#!/bin/bash

echo "Installing Packages"

apt update
apt upgrade -y

apt install -y \
    curl \
    git \
    gh \
    helix \
    lazygit \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    wget

echo "Updating Repositories"

curl -sS https://debian.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/debian.griffo.io.gpgecho "deb https://debian.griffo.io/apt $(lsb_release -sc 2>/dev/null) main"
echo "deb https://debian.griffo.io/apt $(lsb_release -sc 2>/dev/null) main" | sudo tee /etc/apt/sources.list.d/debian.griffo.io.list

apt update
apt install helix

echo "Installing UV"

wget -qO- https://astral.sh/uv/install.sh | sh

source ~/.bashrc

uvx install ruff
uvx install ty
uvx install python-lsp-server

