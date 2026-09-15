#!/bin/bash

source ./sh/vllm-docker-stop-and-remove.sh

docker pull vllm/vllm-openai-rocm:nightly

docker run -d
  --restart unless-stopped \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add render \
  --group-add video \
  --name vllm \
  --label autoheal=true \
  --privileged \
  --ipc=host -p 8000:8000 \
  --health-cmd='curl -f http://localhost:8000/health || exit 1' \
  --health-interval=15s \
  --health-timeout=5s \
  --health-retries=3 \
  --health-start-period=600s \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  vllm/vllm-openai-rocm:nightly cyankiwi/K2-Horizon-MoVA-36B-A4B-AWQ-INT4 \
  --served-model-name 'dandy.dash' \
  --trust-remote-code \
  --enable-expert-parallel \
  --gpu-memory-utilization 0.90 \
  --kv-cache-dtype fp8 \
  --tensor-parallel-size 2 \
  --reasoning-parser k2_horizon \
  --enable-auto-tool-choice \
  --tool-call-parser k2_horizon \
  --enable-prefix-caching \
  --default-chat-template-kwargs '{"reasoning_effort": "low"}'

source ./sh/vllm-docker-restart-service-install.sh