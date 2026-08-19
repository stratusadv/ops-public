#!/bin/bash

echo "Setting Up VLLM Docker Restart Service"

cp vllm-docker-restart.service /etc/systemd/system/vllm-docker-restart.service
cp vllm-docker-restart.timer /etc/systemd/system/vllm-docker-restart.timer

systemctl enable --now vllm-docker-restart.timer