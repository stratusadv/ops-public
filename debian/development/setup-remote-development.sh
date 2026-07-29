#!/bin/bash

echo "Installing Packages"

apt update
apt upgrade -y

apt install -y \
    curl \
    git \
    gh \
    lazygit \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    wget

echo "Updating Repositories"

sudo add-apt-repository ppa:maveonair/helix-editor
sudo apt update
sudo apt install helix

echo "Installing UV"

wget -qO- https://astral.sh/uv/install.sh | sh

source ~/.bashrc

uv tool install ruff
uv tool install ty
uv tool install python-lsp-server

