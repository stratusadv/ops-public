#!/bin/bash

# 2 x NVIDIA RTX 6000 Pro Blackwell (96 GB each) + 64 GB RAM (+ 64 GB swapfile from os-nvidia-setup.sh)
#
# Checkpoint: nvidia/Qwen3.8-Flash-Next-NVFP4 (132.7 GB on disk)
#   - 79.0 GB NVFP4 main weights (dense + MoE) -> 39.5 GB/GPU at TP2
#   - 51.2 GB n-gram PLE table, F8_E4M3 (dedicated model-fp8-mtp-ple.safetensors, +2.5 GB BF16 MTP)
# Fallback: swap the model ref to Qwen/Qwen3.8-Flash-Next-FP8 (185.5 GB; 67 GB/GPU on-GPU weights)
# if the NVFP4 path misbehaves on first boot — everything else in this script stays the same.
#
# PLE (n-gram embedding) CPU offload: the 51.2 GB FP8 n-gram table lives in host RAM and is
# asynchronously row-prefetched (VLLM_PLE_CPU_OFFLOAD=1). This is what makes TP2 possible here —
# without it the table does not fit on GPU alongside the weights.
#
# Host RAM budget: 51.2 GB table + runtime headroom in 64 GB RAM, swapfile absorbs load staging.
# 128 GB RAM is comfortable; 64 GB is the working minimum.
#
# Recipe: https://recipes.vllm.ai/Qwen/Qwen3.8-Flash-Next (PyPI/venv install is NOT supported for this model)
# Note: PLE offload is recipe-validated on the FP8 checkpoint; NVFP4 is the NVIDIA-published
# hybrid with the identical 51.2 GB FP8 table (same shape/dtype, verified from shard headers).

source ../sh/vllm-docker-stop-and-remove.sh

docker pull vllm/vllm-openai:qwen38-flash-next

docker run -d --restart unless-stopped --gpus all \
  --name vllm \
  --label autoheal=true \
  --privileged --ipc=host -p 8000:8000 \
  --health-cmd='curl -f http://localhost:8000/health || exit 1' \
  --health-interval=15s \
  --health-timeout=5s \
  --health-retries=3 \
  --health-start-period=600s \
  -e VLLM_PLE_CPU_OFFLOAD=1 \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  vllm/vllm-openai:qwen38-flash-next nvidia/Qwen3.8-Flash-Next-NVFP4 \
  --served-model-name 'stratus.thinking' \
  --enable-auto-tool-choice \
  --enable-expert-parallel \
  --enable-prefix-caching \
  --no-enable-flashinfer-autotune \
  --kv-cache-dtype fp8 \
  --attention-config.indexer_kv_dtype fp8 \
  --gpu-memory-utilization 0.90 \
  --max-num-seqs 256 \
  --reasoning-parser qwen3 \
  --speculative-config '{"method": "mtp", "num_speculative_tokens": 3}' \
  --tensor-parallel-size 2 \
  --tool-call-parser qwen3_coder \
  --trust-remote-code

source ../sh/vllm-docker-restart-service-install.sh
