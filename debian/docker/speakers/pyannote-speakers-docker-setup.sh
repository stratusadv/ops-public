#!/bin/bash

set -euo pipefail

if [ -f /etc/environment ]; then
    set -a
    source /etc/environment
    set +a
fi

HF_TOKEN="${HF_TOKEN:-}"
VLLM_API_KEY="${VLLM_API_KEY:-}"

source ../sh/speakers-docker-stop-and-remove.sh || true

docker build -t stratus/speakers:latest .

docker run -d --restart unless-stopped --gpus all \
  --name speakers \
  --label autoheal=true \
  -p 8001:8001 \
  --health-cmd='curl -f http://localhost:8001/health || exit 1' \
  --health-interval=15s \
  --health-timeout=5s \
  --health-retries=3 \
  --health-start-period=600s \
  -e "HF_TOKEN=${HF_TOKEN}" \
  -e "VLLM_API_KEY=${VLLM_API_KEY}" \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  stratus/speakers:latest
