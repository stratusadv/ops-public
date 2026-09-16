#!/bin/bash

source ./sh/vllm-docker-stop-and-remove.sh

docker pull vllm/vllm-openai-rocm:latest

docker run -d \
  --restart unless-stopped \
  --name vllm \
  --label autoheal=true \
  --privileged \
  --ipc=host \
  --network=host \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  -e HIP_VISIBLE_DEVICES=0,1 \
  -e ROCR_VISIBLE_DEVICES=0,1 \
  -e HSA_ENABLE_SDMA=0 \
  -e NCCL_P2P_DISABLE=1 \
  -e RCCL_P2P_DISABLE=1 \
  -e NCCL_SHM_DISABLE=1 \
  -e NCCL_SOCKET_IFNAME=lo \
  -e NCCL_DEBUG=INFO \
  -e NCCL_PROTO=Simple \
  -p 8000:8000 \
  --health-cmd='curl -f http://localhost:8000/health || exit 1' \
  --health-interval=15s \
  --health-timeout=5s \
  --health-retries=3 \
  --health-start-period=600s \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  vllm/vllm-openai-rocm:latest amd/Qwen3.8-27B-Quark-AWQ-INT4-W4A16 \
  --served-model-name 'dandy.dash' \
  --trust-remote-code \
  --enforce-eager \
  --gpu-memory-utilization 0.90 \
  --kv-cache-dtype fp8 \
  --tensor-parallel-size 2 \
  --disable-custom-all-reduce \
  --tool-call-parser qwen3_coder \
  --enable-auto-tool-choice \
  --reasoning-parser qwen3 \
  --enable-prefix-caching \
  --default-chat-template-kwargs '{"reasoning_effort": "low"}'

source ./sh/vllm-docker-restart-service-install.sh