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

# Use a dedicated service environment file instead of the global OS file
ENV_FILE="/etc/environment"

# Create the file if it doesn't exist
touch "$ENV_FILE"

read -sp "Enter Hugging Face Token (hit enter to skip): " NEW_HF_TOKEN
echo "" # Add a newline after silent prompt

# If user entered a token, replace/add it in the env file
if [ -n "$NEW_HF_TOKEN" ]; then
    # Remove existing HF_TOKEN line if it exists, then append the new one
    sed -i '/^HF_TOKEN=/d' "$ENV_FILE"
    echo "HF_TOKEN=$NEW_HF_TOKEN" >> "$ENV_FILE"
    echo "✅ API key saved"
else
    echo "ℹ️ Keeping existing HF_TOKEN (if any)"
fi

# Safely add or update UV_TORCH_BACKEND
sed -i '/^UV_TORCH_BACKEND=/d' "$ENV_FILE"
echo "UV_TORCH_BACKEND=cu130" >> "$ENV_FILE"

# Source the file so we can check if HF_TOKEN is actually set
source "$ENV_FILE"

if [ -z "$HF_TOKEN" ]; then
    echo "❌ Error: HF_TOKEN not set in $ENV_FILE"
    echo "   Make sure to provide the token during the install steps"
    exit 1
fi

# Explicitly use the absolute path for the virtual environment
uv venv /root/vllm-venv
source /root/vllm-venv/bin/activate

uv pip install qwen-asr[vllm]
uv pip install vllm[audio]
uv pip install -U vllm --torch-backend=auto --extra-index-url https://wheels.vllm.ai/nightly
uv pip install nvidia-cuda-runtime-cu12
uv pip install flashinfer-python --torch-backend=cu130

deactivate

# Ensure these files exist in the directory where the script is run
if [ ! -f "vllm.sh" ] || [ ! -f "vllm.service" ]; then
    echo "❌ Error: vllm.sh or vllm.service not found in current directory"
    exit 1
fi

cp vllm.sh /usr/local/bin/vllm.sh
chmod +x /usr/local/bin/vllm.sh
cp vllm.service /etc/systemd/system/vllm.service

echo "Starting VLLM Service"

systemctl daemon-reload
systemctl enable vllm
systemctl restart vllm

echo "✅ Done"