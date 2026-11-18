#!/bin/bash

# Source system environment variables (including HF_TOKEN from /etc/environment)
if [ -f /etc/environment ]; then
    set -a
    source /etc/environment
    set +a
fi

source ../sh/vllm-docker-stop-and-remove.sh

# Ensure the NVMe offload directory for the N-gram / PLE table exists
mkdir -p /opt/models/ple_cache

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
  -e PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True" \
  -e HF_TOKEN="${HF_TOKEN}" \
  -e VLLM_PLE_DISK_OFFLOAD_DIR="/opt/models/ple_cache" \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  -v /opt/models/ple_cache:/opt/models/ple_cache \
  lmsysorg/sglang:latest \
  python -m sglang.launch_server \
  --model-path nvidia/Qwen3.8-Flash-Next-FP4-Local \
  --served-model-name 'stratus.thinking' \
  --trust-remote-code \
  --host 0.0.0.0 \
  --port 8000 \
  --tp-size 2 \
  --mem-fraction-static 0.88 \
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
  --chunked-prefill-size 2048 \
  --schedule-conservativeness 0.3 \
  --max-running-requests 64 \
  --tool-call-parser qwen3_coder \
  --reasoning-parser qwen3 \
  --default-chat-template-kwargs '{"enable_thinking": true}' \
  --speculative-algorithm NEXTN \
  --speculative-num-steps 3 \
  --disable-overlap-schedule

source ../sh/vllm-docker-restart-service-install.sh