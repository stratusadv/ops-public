#!/bin/bash

# stratus.turbo on 2 x RTX 3090 (48GB VRAM): the ternary Bonsai-2-27B model
# (fraserprice/Ternary-Bonsai-2-27B-vllm) served by vLLM through the PrismML
# "prism_ternary" plugin, with DFlash2 speculative decoding. Instruct mode
# (no thinking).
#
# The model is the real ternary 27B (2-bit codes + FP16 g128 scales,
# Hadamard-rotated) repacked as vLLM safetensors. It is NOT loadable by stock
# vllm/vllm-openai - it needs the fraserpricee/bonsai-vllm image, which ships
# the prism_ternary plugin and precompiled CUDA kernels.
#
# Speculative decoding - the SPEC env var:
#   dflash  (default)  DFlash2 draft head ProCreations/Ternary-Bonsai-2-27B-
#              DFlash2 (BF16, 3 draft tokens). The draft is BF16, so unlike the
#              model's built-in MTP drafter (FP8) it avoids Ampere's missing
#              FP8 tensor cores - the more 3090-friendly speculative method.
#   none                 no speculative decoding (bare ternary model). Use this
#              first to confirm the prism_ternary target runs on your 3090,
#              then rerun with SPEC=dflash to add speculative on top.
#
# HARDWARE NOTE (3090 / Ampere SM 8.6): the image is authored for RTX PRO 6000
# Blackwell and "untested" elsewhere, but its kernels ARE built for SM 8.6, so
# the base ternary GEMM is expected to run on a 3090. First boot downloads
# ~9.6GB of weights into the "bonsai" volume (persists across restarts);
# `docker volume rm bonsai` for a clean slate.

SPEC="${SPEC:-dflash}"

source ../sh/vllm-docker-stop-and-remove.sh

docker pull fraserpricee/bonsai-vllm:20260918

SPEC_ARGS=()
case "$SPEC" in
  dflash)
    SPEC_ARGS=(--speculative-config '{"method":"dflash","model":"ProCreations/Ternary-Bonsai-2-27B-DFlash2","num_speculative_tokens":3}')
    ;;
  none)
    ;;
  *)
    echo "❌ unknown SPEC='$SPEC' (expected dflash or none)"
    exit 1
    ;;
esac

docker run -d --restart unless-stopped --gpus all \
  --name vllm \
  --label autoheal=true \
  --privileged --ipc=host -p 8000:8000 \
  --health-cmd='curl -f http://localhost:8000/health || exit 1' \
  --health-interval=15s \
  --health-timeout=5s \
  --health-retries=3 \
  --health-start-period=600s \
  -v bonsai:/cache \
  --entrypoint vllm \
  fraserpricee/bonsai-vllm:20260918 \
  serve fraserprice/Ternary-Bonsai-2-27B-vllm \
  --served-model-name 'stratus.turbo' \
  --max-model-len 32768 \
  --max-num-seqs 32 \
  --max-num-batched-tokens 8192 \
  --gpu-memory-utilization 0.90 \
  --enable-prefix-caching \
  --enable-chunked-prefill \
  --language-model-only \
  --trust-remote-code \
  --reasoning-parser qwen3 \
  --enable-auto-tool-choice \
  --tool-call-parser qwen3_xml \
  --default-chat-template-kwargs '{"enable_thinking": false}' \
  "${SPEC_ARGS[@]}"

source ../sh/vllm-docker-restart-service-install.sh

if [ "$SPEC" = "dflash" ]; then
  echo "✅ stratus.turbo (ternary Bonsai-2-27B) started. DFlash2 speculative: ON (3 tokens, BF16 draft)."
else
  echo "✅ stratus.turbo (ternary Bonsai-2-27B) started. Speculative: OFF (set SPEC=dflash to enable DFlash2)."
fi
