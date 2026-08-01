#!/bin/bash

docker pull vllm/vllm-openai:latest

docker run --gpus all \
  --privileged --ipc=host -p 8000:8000 \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  vllm/vllm-openai:latest auroter/DeepSeek-V4-Flash-0731-NVFP4 \
  --trust-remote-code \
  --kv-cache-dtype fp8 \
  --gpu-memory-utilization 0.97 \
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