#!/bin/bash

source ./sh/vllm-docker-stop-and-remove.sh

docker pull vllm/vllm-openai-rocm:latest

docker run -d \
  --restart unless-stopped \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  -e NCCL_PROTO=Simple \
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
  vllm/vllm-openai-rocm:latest Qwen/Qwen3.8-27B-FP8 \
  --served-model-name 'dandy.dash' \
  --trust-remote-code \
  --enforce-eager \
  --gpu-memory-utilization 0.90 \
  --kv-cache-dtype fp8 \
  --tensor-parallel-size 2 \
  --tool-call-parser qwen3_coder \
  --enable-auto-tool-choice \
  --reasoning-parser qwen3 \
  --enable-prefix-caching \
  --speculative-config '{"method": "mtp", "num_speculative_tokens": 2}' \
  --default-chat-template-kwargs '{"reasoning_effort": "low"}'


source ./sh/vllm-docker-restart-service-install.sh