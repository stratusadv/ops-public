#!/bin/bash

echo "Setting up Remote Development"

apt update
apt upgrade -y

apt install -y \
    build-essential \
    curl \
    git \
    gh \
    hx \
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

hx --grammar fetch
hx --grammar build
hx --health python

echo "✅ Done"