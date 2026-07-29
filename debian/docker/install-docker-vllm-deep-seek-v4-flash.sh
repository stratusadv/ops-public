#!/bin/bash

docker pull vllm/vllm-openai:latest

docker run --gpus all \
  --privileged --ipc=host -p 8000:8000 \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  vllm/vllm-openai:latest nvidia/DeepSeek-V4-Flash-NVFP4 \
  --trust-remote-code \
  --kv-cache-dtype fp8 \
  --block-size 256 \
  --enable-expert-parallel \
  --tensor-parallel-size 2 \
  --attention_config.use_fp4_indexer_cache=True \
  --max-model-len 262144 \
  --tokenizer-mode deepseek_v4 \
  --tool-call-parser deepseek_v4 \
  --enable-auto-tool-choice \
  --reasoning-parser deepseek_v4\
  --default-chat-template-kwargs '{ "enable_thinking": true, "reasoning_effort": "max" }'
