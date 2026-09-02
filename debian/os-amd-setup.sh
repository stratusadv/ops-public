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
    python3-setuptools \
    python3-wheel \
    wget

echo "Installing UV"

wget -qO- https://astral.sh/uv/install.sh | sh

echo "Installing AMDGPU Driver and ROCm ..."

AMDGPU_INSTALLER="amdgpu-install_7.2.4.70204-1_all.deb"

if command -v rocminfo &> /dev/null; then
    echo "ROCm is already installed. Skipping AMDGPU driver and ROCm installation."
else
    echo "ROCm not found. Preparing to install..."

    if [ ! -f "$AMDGPU_INSTALLER" ]; then
        echo "Downloading amdgpu-install package..."
        wget "https://repo.radeon.com/amdgpu-install/7.2.4/ubuntu/noble/$AMDGPU_INSTALLER"
    else
        echo "Installer $AMDGPU_INSTALLER already exists locally. Skipping download."
    fi

    echo "Installing amdgpu-install package..."
    apt install -y "./$AMDGPU_INSTALLER"

    echo "Updating package lists with AMD repositories..."
    apt update

    echo "Installing AMDGPU DKMS kernel driver and full ROCm stack..."
    apt install -y amdgpu-dkms rocm

    echo "Loading amdgpu kernel module..."
    modprobe amdgpu
fi

echo "Verifying GPU detection..."
rocminfo
amd-smi list

echo "Done ... We recommend rebooting after this process or if the AMDGPU installer fails!"