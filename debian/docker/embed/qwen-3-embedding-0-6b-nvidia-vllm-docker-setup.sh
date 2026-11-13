#!/bin/bash

set -euo pipefail

if [ -f /etc/environment ]; then
    set -a
    source /etc/environment
    set +a
fi

EMBED_GPU="${EMBED_GPU:?set it in /etc/environment}"
EMBED_GPU_MEMORY_UTILIZATION="${EMBED_GPU_MEMORY_UTILIZATION:?set it in /etc/environment}"
VLLM_TAG="${VLLM_TAG:-latest}"

docker stop vllm-embed || true

docker container rm vllm-embed || true

docker run -d --restart unless-stopped --gpus "device=${EMBED_GPU}" \
  --name vllm-embed \
  --label autoheal=true \
  --ipc=host -p 8002:8000 \
  --health-cmd='curl -f http://localhost:8000/health || exit 1' \
  --health-interval=15s \
  --health-timeout=5s \
  --health-retries=3 \
  --health-start-period=600s \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  vllm/vllm-openai:"${VLLM_TAG}" Qwen/Qwen3-Embedding-0.6B \
  --served-model-name 'stratus.embed' \
  --runner pooling \
  --convert embed \
  --gpu-memory-utilization "${EMBED_GPU_MEMORY_UTILIZATION}" \
  --max-model-len 8192 \
  --max-num-batched-tokens 8192
