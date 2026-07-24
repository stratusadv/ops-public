#!/bin/bash

if [ ! -f "vllm.sh" ] || [ ! -f "vllm.service" ]; then
    echo "❌ Error: vllm.sh or vllm.service not found in current directory"
    exit 1
fi

cp vllm.sh /usr/local/bin/vllm.sh
chmod +x /usr/local/bin/vllm.sh
cp vllm.service /etc/systemd/system/vllm.service
cp vllm-restart.service /etc/systemd/system/vllm-restart.service
cp vllm-restart.timer /etc/systemd/system/vllm-restart.timer

echo "Starting VLLM Service"


systemctl daemon-reload
systemctl enable --now vllm
systemctl stop vllm
rm -rf /dev/shm/*
systemctl restart vllm
systemctl enable --now vllm-restart.timer