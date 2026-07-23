#!/bin/bash

apt update

apt upgrade -y

apt install g++ freeglut3-dev build-essential libx11-dev libxmu-dev python3-dev libxi-dev libglu1-mesa-dev libfreeimage-dev libglfw3-dev wget htop btop nvtop nano glances git cmake curl libcurl4-openssl-dev dkms proxmox-headers-$(uname -r)

wget -qO- https://astral.sh/uv/install.sh | sh

wget https://developer.download.nvidia.com/compute/cuda/13.1.0/local_installers/cuda_13.1.0_590.44.01_linux.run

chmod +x cuda_13.1.0_590.44.01_linux.run

./cuda_13.1.0_590.44.01_linux.run

