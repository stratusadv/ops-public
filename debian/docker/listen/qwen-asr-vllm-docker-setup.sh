#!/bin/bash

set -euo pipefail

if [ -f /etc/environment ]; then
    set -a
    source /etc/environment
    set +a
fi

VLLM_TAG="${VLLM_TAG:-latest}"
TENSOR_PARALLEL="${TENSOR_PARALLEL:-1}"
HF_TOKEN="${HF_TOKEN:-}"
VLLM_API_KEY="${VLLM_API_KEY:-}"

source ../sh/vllm-docker-stop-and-remove.sh || true

docker build --build-arg "VLLM_TAG=${VLLM_TAG}" -t stratus/listen:"${VLLM_TAG}" .

docker run -d --restart unless-stopped --gpus all \
  --name vllm \
  --label autoheal=true \
  --ipc=host -p 8000:8000 \
  --health-cmd='curl -f http://localhost:8000/health || exit 1' \
  --health-interval=15s \
  --health-timeout=5s \
  --health-retries=3 \
  --health-start-period=600s \
  -e "HF_TOKEN=${HF_TOKEN}" \
  -e "VLLM_API_KEY=${VLLM_API_KEY}" \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  -v "$(pwd)/config.yml:/config.yml:ro" \
  stratus/listen:"${VLLM_TAG}" \
  --config /config.yml \
  --tensor-parallel-size "${TENSOR_PARALLEL}"
