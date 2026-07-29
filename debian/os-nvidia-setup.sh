#!/bin/bash

echo "Setting Up Operating System ..."

SWAP_FILE="/swapfile"
SWAP_SIZE_GB=64

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root (e.g., sudo ./setup_swap.sh)"
  exit 1
fi

echo "Disabling existing swap..."
swapoff -a

echo "Allocating ${SWAP_SIZE_GB}GB to $SWAP_FILE..."
if ! fallocate -l "${SWAP_SIZE_GB}G" "$SWAP_FILE" 2>/dev/null; then
    echo "fallocate not supported on this filesystem. Falling back to dd..."
    dd if=/dev/zero of="$SWAP_FILE" bs=1G count="$SWAP_SIZE_GB" status=progress
fi

echo "Setting strict permissions..."
chmod 600 "$SWAP_FILE"

echo "Formatting swap space..."
mkswap "$SWAP_FILE"

echo "Enabling swap..."
swapon "$SWAP_FILE"

echo "Ensuring persistence in /etc/fstab..."
if ! grep -q "^$SWAP_FILE" /etc/fstab; then
    echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
    echo "Added $SWAP_FILE to /etc/fstab."
else
    echo "fstab entry already exists."
fi

echo "Done. Current memory and swap status:"
free -h

echo "Updating Operating System ..."

apt update

echo "Upgrading Operating System ..."

apt upgrade -y

echo "Installing required Applications ..."

apt install -y \
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

echo "Installing UV"

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

echo "Done ... We recommend rebooting after this process or if the CUDA installer fails!"

