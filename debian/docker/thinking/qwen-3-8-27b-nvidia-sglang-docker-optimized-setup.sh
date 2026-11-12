#!/bin/bash

source ../sh/vllm-docker-stop-and-remove.sh

docker pull lmsysorg/sglang:latest

docker run -d --restart unless-stopped --gpus all \
  --name vllm \
  --label autoheal=true \
  --privileged --ipc=host -p 8000:8000 \
  --health-cmd='curl -f http://localhost:8000/health || exit 1' \
  --health-interval=15s \
  --health-timeout=5s \
  --health-retries=3 \
  --health-start-period=900s \
  -e SGLANG_JIT_DEEPGEMM_FAST_WARMUP=1 \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  lmsysorg/sglang:latest \
  python -m sglang.launch_server \
  --model-path Qwen/Qwen3.8-27B-FP8 \
  --served-model-name 'stratus.thinking' \
  --trust-remote-code \
  --host 0.0.0.0 \
  --port 8000 \
  --tp-size 2 \
  --mem-fraction-static 0.90 \
  --attention-backend flashinfer \
  --context-length 262144 \
  --kv-cache-dtype bfloat16 \
  --mamba-ssm-dtype bfloat16 \
  --mamba-radix-cache-strategy extra_buffer \
  --max-mamba-cache-size 256 \
  --page-size 64 \
  --enable-hierarchical-cache \
  --hicache-size 10 \
  --hicache-write-policy write_back \
  --weight-loader-drop-cache-after-load \
  --enable-cache-report \
  --chunked-prefill-size 1024 \
  --schedule-conservativeness 0.5 \
  --max-running-requests 24 \
  --tool-call-parser qwen3_coder \
  --reasoning-parser qwen3 \
  --default-chat-template-kwargs '{"enable_thinking": true}' \
  --speculative-algorithm DFLASH \
  --speculative-draft-model-path incoai/Qwen3.8-27B-DFlash2 \
  --speculative-num-draft-tokens 6 \
  --disable-overlap-schedule

source ../sh/vllm-docker-restart-service-install.sh