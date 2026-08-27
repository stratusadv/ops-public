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
  vllm/vllm-openai:latest auroter/DeepSeek-V4-Flash-0731-NVFP4 \
  --served-model-name 'stratus.thinking' \
  --block-size 256 \
  --compilation-config '{"cudagraph_mode":"FULL_DECODE_ONLY"}' \
  --cpu-offload-gb 32 \
  --enable-auto-tool-choice \
  --enable-expert-parallel \
  --enable-prefix-caching \
  --gpu-memory-utilization 0.95 \
  --kv-cache-dtype fp8 \
  --max-model-len 262144 \
  --max-num-seqs 2 \
  --moe-backend auto \
  --reasoning-config '{"reasoning_parser":"deepseek_v4","reasoning_start_str":"","reasoning_end_str":""}' \
  --reasoning-parser deepseek_v4 \
  --speculative-config '{"method":"dspark","num_speculative_tokens":5}' \
  --tensor-parallel-size 2 \
  --tokenizer-mode deepseek_v4 \
  --tool-call-parser deepseek_v4 \
  --trust-remote-code

source ./sh/vllm-docker-restart-service-install.sh