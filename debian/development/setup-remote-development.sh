#!/bin/bash

echo "Installing Packages"

add-apt-repository ppa:maveonair/helix-editor

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

echo "Installing UV"

wget -qO- https://astral.sh/uv/install.sh | sh

source ~/.bashrc

uv tool install ruff
uv tool install ty
uv tool install python-lsp-server

