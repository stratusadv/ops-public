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
  vllm/vllm-openai:qwen38-flash-next Inferact/Qwen3.8-Flash-Next-NVFP4 \
  --served-model-name 'stratus.thinking' \
  --enable-auto-tool-choice \
  --no-enable-flashinfer-autotune \
  --enable-prefix-caching \
  --kv-cache-dtype fp8 \
  --gpu-memory-utilization 0.95 \
  --tensor-parallel-size 2 \
  --max-model-len 262144 \
  --max-num-seqs 256 \
  --reasoning-parser qwen3 \
  --speculative-config '{"method": "mtp", "num_speculative_tokens": 3}' \
  --tool-call-parser qwen3_coder \
  --trust-remote-code

source ./sh/vllm-docker-restart-service-install.sh