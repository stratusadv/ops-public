#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

echo "Installing Nvidia Power Service ... "

cp set-nvidia-gpu-power-limit.sh /usr/local/bin/set-nvidia-gpu-power-limit.sh

chmod +x /usr/local/bin/set-nvidia-gpu-power-limit.sh

cp nvidia-power.service /etc/systemd/system/nvidia-power.service

systemctl daemon-reload

systemctl enable nvidia-power

systemctl start nvidia-power

nvidia-smi -q -d POWER

echo "✅ Done"