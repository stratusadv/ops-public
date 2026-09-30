#!/bin/bash

# stratus.turbo on 2 x RTX 3090 (48GB VRAM): AWQ INT4 target (Ampere-safe,
# no FP8 tensor cores) with the ProCreations DFlash2 draft head. Instruct
# mode (no thinking). Context 32768 is the draft head's tested context.
#
# FALLBACK: the primary 3090 turbo deployment is now
# ternary-bonsai-2-27b-nvidia-vllm-docker-setup.sh (ternary Bonsai on vLLM).
# This script stays as the known-good Ampere-safe fallback if that build does
# not run on your 3090.

source ../sh/vllm-docker-stop-and-remove.sh

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
  vllm/vllm-openai:latest cyankiwi/Qwen3.8-27B-AWQ-INT4 \
  --served-model-name 'stratus.turbo' \
  --trust-remote-code \
  --gpu-memory-utilization 0.90 \
  --tensor-parallel-size 2 \
  --max-model-len 32768 \
  --tool-call-parser qwen3_xml \
  --enable-auto-tool-choice \
  --enable-chunked-prefill \
  --enable-prefix-caching \
  --reasoning-parser qwen3 \
  --default-chat-template-kwargs '{"enable_thinking": false}' \
  --speculative-config '{"method":"dflash","model":"ProCreations/Ternary-Bonsai-2-27B-DFlash2","num_speculative_tokens":3}'

source ../sh/vllm-docker-restart-service-install.sh
