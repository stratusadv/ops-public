#!/bin/bash

apt update

apt upgrade -y

apt install -y \
    btop \
    build-essential \
    cmake \
    curl \
    dkms \
    freeglut3-dev \
    g++ \
    git \
    glances \
    htop \
    libcurl4-openssl-dev \
    libfreeimage-dev \
    libglfw3-dev \
    libglu1-mesa-dev \
    libx11-dev \
    libxi-dev \
    libxmu-dev \
    nano \
    nvtop \
    proxmox-headers-$(uname -r) \
    python3-dev \
    wget

wget -qO- https://astral.sh/uv/install.sh | sh

INSTALLER="cuda_13.3.1_610.43.02_linux.run"

if command -v nvidia-smi &> /dev/null; then
    echo "NVIDIA driver is already installed. Skipping CUDA download and installation. run 'nvidia-uninstall' to remove it"
else
    echo "NVIDIA driver not found. Preparing to install..."

    if [ ! -f "$INSTALLER" ]; then
        echo "Downloading CUDA installer..."
        wget "https://developer.download.nvidia.com/compute/cuda/13.3.1/local_installers/$INSTALLER"
    else
        echo "Installer $INSTALLER already exists locally. Skipping download."
    fi

    echo "Running CUDA installer..."
    bash "$INSTALLER" --silent
fi

echo "We recommend rebooting after this process is complete"

