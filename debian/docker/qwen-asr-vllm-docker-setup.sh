#!/bin/bash

source ./sh/vllm-docker-stop-and-remove.sh

docker pull vllm/vllm-openai:latest

docker run -d --restart unless-stopped --gpus all \
  --name vllm \
  --label autoheal=true \
  --privileged --ipc=host -p 8000:8000 \
  --health-cmd='curl -f http://localhost:8000/health || exit 1' \
  --health-interval=15s \
  --health-timeout=5s \
  --health-retries=3 \
  --health-start-period=600s \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  vllm/vllm-openai:latest Qwen/Qwen3-ASR-1.7B \
  --served-model-name 'stratus.listen' \
  --trust-remote-code \
  --max-num-seqs: 32 \
  --enable-prefix-caching \
  --gpu-memory-utilization 0.85

source ./sh/vllm-docker-restart-service-install.sh