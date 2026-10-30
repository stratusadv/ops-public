#!/bin/bash

# stratus.thinking on 2 x RTX 6000 Pro Blackwell (2 x 96GB) via SGLang:
# Qwen3.8-27B first-party blockwise FP8 (dynamic, 128x128 blocks; SGLang
# detects the checkpoint quantization itself, so no --quantization flag).
# SGLang was picked for the engine here: RadixAttention prefix caching plus
# first-class hybrid-GDN support are exactly what a coding-agent fleet needs
# (long conversations that re-send their whole prefix every tool round).
#
# --dp-size 2: the 27B FP8 model fits on a single 96GB GPU, so this runs two
# independent replicas (one per GPU) instead of TP2. That doubles the
# concurrent session slots, removes the per-token allreduce, and keeps a slow
# prefill on one replica from stalling the other's decode (same DP pattern as
# the vLLM Blackwell coder configs).
#
# Thinking is ON by default: agentic coding lives on multi-step reasoning
# (planning the fix, interpreting tool output, self-correcting before the
# next command), and Qwen3.8's quality ceiling on those tasks is in thinking
# mode (the model family also defaults to thinking, as the vLLM
# stratus.thinking endpoint does). The per-round latency tax is the real cost,
# and it is mitigated here twice: the MTP head (NEXTN) accepts thinking tokens
# well, so they decode faster than plain sampling, and what agents pay for is
# total rounds, not per-token latency - a slow round that avoids three
# rework rounds wins. Cheap/fast calls can still opt out per request with
# chat_template_kwargs {"enable_thinking": false}. preserve_thinking is NOT
# set: re-rendering every past thinking block would burn the 256K window.
#
# 256K context, hybrid GDN memory model (48 linear-attention + 16 full-
# attention layers):
# - Every session holds ~150MB of fp32 GDN recurrent state regardless of
#   context length, so the mamba pool - not the attention KV - is the real
#   concurrency cap. --mamba-ssm-dtype bfloat16 halves that state (the HF
#   config pins float32; SGLang honors the override).
# - Full-attention KV stays bfloat16 (the production-verified recipe for this
#   checkpoint keeps it out of fp8 for quality; ~64KiB/token). At 0.85
#   mem-fraction-static per GPU the KV pool holds ~450K tokens per replica,
#   i.e. ~1-2 full 256K sessions resident per replica (~3-4 per node); most
#   agent sessions live far below the window, so real concurrency is higher.
# - --enable-hierarchical-cache --hicache-size 32: the host-DRAM tier of the
#   radix cache (SGLang HiCache). When the GPU KV pool evicts conversation
#   history, the pages migrate to system RAM instead of being dropped, so a
#   returning agent session reloads its 256K prefix over PCIe (~0.3s for a
#   full session) instead of re-prefilling it (tens of seconds). 32GB keeps
#   the agents themselves and the OS fed on the same 64GB host; raise toward
#   48 if the agents run elsewhere. Only full-attention KV is offloaded; the
#   GDN state stays on GPU, so concurrency limits are unchanged.
#
# Agent-specific tuning:
# - --mamba-radix-cache-strategy extra_buffer + --page-size 64: caches GDN
#   state at branch points, so a retried or branched agent turn resumes from
#   the fork instead of re-prefilling. Page size 64 is required by the FLA
#   chunk constraint for this strategy.
# - --disable-overlap-schedule: SGLang's speculative V2 has a request-
#   dependent overlap-path crash on hybrid Mamba models; production Qwen3.8
#   SGLang deployments disable it. Re-enable once that lands upstream.
# - --speculative-algorithm NEXTN (3 steps, topk 1, 4 draft tokens): drives
#   the MTP head baked into the FP8 checkpoint - no separate draft model to
#   download (and none to keep unquantized, unlike the vLLM dflash head).
# - --attention-backend flashinfer + --chunked-prefill-size 2048: the
#   Blackwell (SM120) recipe values verified on this card.
#
# Sampling: SGLang serves the checkpoint's generation_config (temp 1.0,
# top_p 0.95, top_k 20) as the default for requests that send nothing, and
# per-request sampling from the agent always wins. If a server-enforced
# recipe is wanted, front this with sgl-router:
# --override-sampling-params '{"temperature":1.0,"top_p":0.95,"top_k":20}'
# (the official Qwen3.8 thinking recipe).

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
  --dp-size 2 \
  --mem-fraction-static 0.90 \
  --attention-backend flashinfer \
  --context-length 262144 \
  --kv-cache-dtype bfloat16 \
  --mamba-ssm-dtype bfloat16 \
  --mamba-radix-cache-strategy extra_buffer \
  --page-size 64 \
  --enable-hierarchical-cache \
  --hicache-size 32 \
  --hicache-write-policy write_through \
  --chunked-prefill-size 2048 \
  --max-running-requests 32 \
  --tool-call-parser qwen3_coder \
  --reasoning-parser qwen3 \
  --default-chat-template-kwargs '{"enable_thinking": true}' \
  --speculative-algorithm NEXTN \
  --speculative-num-steps 3 \
  --speculative-eagle-topk 1 \
  --speculative-num-draft-tokens 4 \
  --disable-overlap-schedule

source ../sh/vllm-docker-restart-service-install.sh
