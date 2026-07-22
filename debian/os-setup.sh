#!/bin/bash

apt update

apt upgrade -y

apt install g++ freeglut3-dev build-essential libx11-dev libxmu-dev libxi-dev libglu1-mesa-dev libfreeimage-dev libglfw3-dev wget htop btop nvtop nano glances git cmake curl libcurl4-openssl-dev

wget -qO- https://astral.sh/uv/install.sh | sh



