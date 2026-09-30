#!/bin/bash

# stratus.turbo on 2 x RTX 3090 (48GB VRAM): Qwen3.8-27B AWQ INT4 (Ampere-safe,
# no FP8 tensor cores) with the incoai Qwen3.8-27B DFlash2 draft head (7 draft
# tokens). Instruct mode (no thinking) - enable_thinking off. Context 65536,
# max-num-batched-tokens 4096. KV cache fp8 (8-bit, ~2x compression; a storage
# dtype that works on Ampere, keeps 64K sessions cheap so more run
# concurrently). Server-side sampling defaults
# (--override-generation-config): temp 0.7, top_p 0.8, top_k 20, min_p 0.0,
# presence_penalty 1.5, repetition_penalty 1.0.

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
  --kv-cache-dtype fp8 \
  --tensor-parallel-size 2 \
  --max-model-len 65536 \
  --max-num-batched-tokens 4096 \
  --tool-call-parser qwen3_xml \
  --enable-auto-tool-choice \
  --enable-chunked-prefill \
  --enable-prefix-caching \
  --reasoning-parser qwen3 \
  --default-chat-template-kwargs '{"enable_thinking": false}' \
  --override-generation-config '{"temperature": 0.7, "top_p": 0.8, "top_k": 20, "min_p": 0.0, "presence_penalty": 1.5, "repetition_penalty": 1.0}' \
  --speculative-config '{"method":"dflash","model":"incoai/Qwen3.8-27B-DFlash2","num_speculative_tokens":7}'

source ../sh/vllm-docker-restart-service-install.sh
