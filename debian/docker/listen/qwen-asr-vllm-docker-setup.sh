#!/bin/bash

set -euo pipefail

VLLM_TAG="${VLLM_TAG:-latest}"
TENSOR_PARALLEL="${TENSOR_PARALLEL:-1}"

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
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  -v "$(pwd)/config.yml:/config.yml:ro" \
  stratus/listen:"${VLLM_TAG}" \
  --config /config.yml \
  --tensor-parallel-size "${TENSOR_PARALLEL}"
