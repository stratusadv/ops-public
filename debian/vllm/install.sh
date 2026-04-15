#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

echo "Installing VLLM Service ..."

VLLM_CONFIG_FILE="/root/vllm-config.yml"

# Check file exists
if [ ! -f "$VLLM_CONFIG_FILE" ]; then
    echo "❌ Error: $VLLM_CONFIG_FILE not found"
    echo "   Make a new one or copy an existing one from the provided configs"
    exit 1
fi

read -sp "Enter Hugging Face Token (hit enter to skip): " HF_TOKEN

ENV_FILE="/etc/environment"

# Only update if user entered something new
if [ -n "$HF_TOKEN" ]; then
    echo "HF_TOKEN=$HF_TOKEN" > "$ENV_FILE"
    echo "✅ API key saved"
else
    echo "ℹ️ Keeping existing HF_TOKEN"
fi

echo "UV_TORCH_BACKEND=cu130" > "$ENV_FILE"

source "$ENV_FILE"

uv venv vllm-venv

source /root/vllm-venv/bin/activate

if [ -z "$HF_TOKEN" ]; then
    echo "❌ Error: HF_TOKEN not set in $ENV_FILE"
    echo "   Make sure to add the token in the install steps"
    exit 1
fi

uv pip install vllm --torch-backend=auto

deactivate

cp vllm.sh /usr/local/bin/vllm.sh

chmod +x /usr/local/bin/vllm.sh

cp vllm.service /etc/systemd/system/vllm.service

systemctl daemon-reload

systemctl enable vllm

systemctl start vllm

echo "Done"