#!/bin/bash

docker pull vllm/vllm-openai:latest

docker run -d --restart unless-stopped --gpus all \
  --name deepseek_v4 \
  --label autoheal=true \
  --privileged --ipc=host -p 8000:8000 \
  --health-cmd="curl -f http://localhost:8000/health || exit 1" \
  --health-interval=10s \
  --health-timeout=5s \
  --health-retries=5 \
  --health-start-period=600s \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  vllm/vllm-openai:latest auroter/DeepSeek-V4-Flash-0731-NVFP4 \
  --served-model-name 'stratus.thinking-max' \
  --trust-remote-code \
  --kv-cache-dtype fp8 \
  --gpu-memory-utilization 0.95 \
  --block-size 256 \
  --tensor-parallel-size 2 \
  --max-model-len 262144 \
  --max-num-seqs 2 \
  --tokenizer-mode deepseek_v4 \
  --tool-call-parser deepseek_v4 \
  --enable-auto-tool-choice \
  --reasoning-parser deepseek_v4 \
  --default-chat-template-kwargs '{ "enable_thinking": true, "reasoning_effort": "max" }' \
  --compilation-config '{"cudagraph_mode":"FULL_DECODE_ONLY"}'