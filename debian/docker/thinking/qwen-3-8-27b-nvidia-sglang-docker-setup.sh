#!/bin/bash

# stratus.thinking on 2 x RTX 6000 Pro Blackwell (2 x 96GB) via SGLang:
# Qwen3.8-27B first-party blockwise FP8 (dynamic, 128x128 blocks; SGLang
# detects the checkpoint quantization itself, so no --quantization flag).
# SGLang was picked for the engine here: RadixAttention prefix caching plus
# first-class hybrid-GDN support are exactly what a coding-agent fleet needs
# (long conversations that re-send their whole prefix every tool round).
#
# --tp-size 2: the 27B FP8 model fits on a single 96GB GPU, but this runs
# tensor-parallel across both instead of two independent DP2 replicas, because
# the load balancer in front cannot pin sessions to a host: with 4 hosts x 2
# independent radix trees, round-robin gives ~1/8 prefix-cache hit rate and
# nearly every turn is a full re-prefill. TP2 keeps ONE shared radix tree per
# host, so a session's turns all hit the same cache no matter how the LB
# scatters them - the only server-side lever on hit rate. The price is accepted
# and known: per-token allreduce over the PCIe-only link (no NVLink on this
# card) costs step time at batch, and one big prefill throttles every decode
# on the host (DP2 isolated prefills per replica). For a cache-bound agent
# fleet the hit-rate win dominates; per-GPU FLOPs are identical under both
# topologies anyway.
#
# Thinking is ON by default: agentic coding lives on multi-step reasoning
# (planning the fix, interpreting tool output, self-correcting before the
# next command), and Qwen3.8's quality ceiling on those tasks is in thinking
# mode (the model family also defaults to thinking, as the vLLM
# stratus.thinking endpoint does). The per-round latency tax is the real cost,
# and it is mitigated here twice: speculative decoding (the DFlash2 head,
# below) accepts thinking tokens well, so they decode faster than plain
# sampling, and what agents pay for is total rounds, not per-token latency -
# a slow round that avoids three rework rounds wins. Cheap/fast calls can still opt out per request with
# chat_template_kwargs {"enable_thinking": false}. preserve_thinking is NOT
# set: re-rendering every past thinking block would burn the 256K window.
#
# 256K context, hybrid GDN memory model (48 linear-attention + 16 full-
# attention layers):
# - Every session holds ~150MB of GDN recurrent state per slot (~110MB per
#   rank under TP2 - not all of the state shards across ranks) regardless of
#   context length, so the mamba pool - not the attention KV - caps session
#   slots. --mamba-ssm-dtype bfloat16 halves that state (the HF config pins
#   float32; SGLang honors the override). --max-mamba-cache-size 128: TP2 has
#   ONE pool for the whole host (DP2 had one per replica), and 4 state slots
#   per request make 128 slots = exactly 32 concurrent requests, matching
#   what the DP2 setup served. The per-rank cost is 14.2GB (vs the 9.6GB a
#   DP2 replica spent on 64 full slots); the extra ~4.5GB per card comes out
#   of the KV pool.
# - Full-attention KV stays bfloat16 (the production-verified recipe for this
#   checkpoint keeps it out of fp8 for quality; ~61KiB/token full, ~30KiB per
#   rank sharded). At 0.93 mem-fraction-static with the 128-slot mamba cap
#   the sharded KV pool holds ~1.4M tokens of shared cache per host (measured
#   1,400,192 per rank, which includes the DFLASH draft's own 13.4GB-per-rank
#   KV) - the weights and the 3.85GB DFlash2 head (lighter than the 5.19GB
#   MTP head it replaces) also shard across the two ranks - i.e. ~5 full
#   256K sessions resident per host, all visible to every request on it;
#   most agent sessions live far below the window, so real concurrency is
#   higher.
# - --enable-hierarchical-cache --hicache-size 16: the host-DRAM tier of the
#   radix cache (SGLang HiCache). --hicache-size is PER TP RANK: each rank
#   allocates its own host pool holding its shard of every token (pool_host
#   sizes capacity as host_size / per-rank size_per_token), so TP2 at 16
#   spends ~32GB of host RAM on KV + GDN state - the same physical footprint
#   as the DP2 setup's two 16GB replica pools - and the shared cache holds
#   ~2x the tokens because each token's bytes are split across the ranks.
#   The DFLASH draft's KV ALSO gets a host mirror sized to the KV host pool's
#   token count, adding ~3.7GB per rank ON TOP of the budget: measured host
#   demand at 16 is ~19.8GB per rank (~40GB total). The ~28GB of checkpoint
#   page cache left by the mmap weight load would push that past a 64GB host,
#   so --weight-loader-drop-cache-after-load is set: it fadvise(DONTNEED)s
#   each shard as it loads, freeing the cache before the pinned host pools
#   allocate (the first TP2 boot OOMed exactly on the draft sidecar without
#   it). Do NOT double it to 32 for TP2: that is 64GB physical and OOMs the
#   host pool at init on a 64GB box; the realistic ceiling with drop-cache
#   is ~20 (~50GB total). Evicted sessions reload their 256K prefix over
#   PCIe (~0.3s) instead of re-prefilling it (tens of seconds).
#
# Agent-specific tuning:
# - --mamba-radix-cache-strategy extra_buffer + --page-size 64: caches GDN
#   state at branch points, so a retried or branched agent turn resumes from
#   the fork instead of re-prefilling. Page size 64 is required by the FLA
#   chunk constraint for this strategy.
# - --disable-overlap-schedule: SGLang's speculative V2 has a request-
#   dependent overlap-path crash on hybrid Mamba models; production Qwen3.8
#   SGLang deployments disable it. Re-enable once that lands upstream.
# - --speculative-algorithm DFLASH + --speculative-draft-model-path
#   incoai/Qwen3.8-27B-DFlash2 (block 8, ~7 draft tokens per step): a 5-layer
#   2B block-diffusion head, bf16, trained for this exact target - better
#   accept length than the built-in MTP (5.46 vs 5.02, incoai's GSM8K) and
#   ~1.3-1.45x decode at concurrency 32. Keep the official bf16 head, not a
#   W4A16/FP8 repack: quantized dflash heads crash the vLLM 0.30 loader at
#   startup (see AGENTS.md) and the only thing the head contributes is accept
#   length. SGLang's candidate selector reads the target's lm_head directly
#   and rejects quantized ones; this checkpoint keeps it bf16 via
#   modules_to_not_convert, so the FP8 target is safe. The head is not in
#   incoai's H200 benchmark matrix, so sanity-check the spec accept rate in
#   the first boot log.
# - --enable-cache-report: without it the OpenAI API always returns
#   prompt_tokens_details=null (SGLang only attaches cached_tokens when the
#   flag is set), so agent clients see "0 cached tokens" on every request no
#   matter how well the radix cache actually hits. Required for cache-hit
#   telemetry to mean anything.
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
  --tp-size 2 \
  --mem-fraction-static 0.93 \
  --attention-backend flashinfer \
  --context-length 262144 \
  --kv-cache-dtype bfloat16 \
  --mamba-ssm-dtype bfloat16 \
  --mamba-radix-cache-strategy extra_buffer \
  --max-mamba-cache-size 128 \
  --page-size 64 \
  --enable-hierarchical-cache \
  --hicache-size 16 \
  --hicache-write-policy write_through \
  --weight-loader-drop-cache-after-load \
  --enable-cache-report \
  --chunked-prefill-size 2048 \
  --max-running-requests 32 \
  --tool-call-parser qwen3_coder \
  --reasoning-parser qwen3 \
  --default-chat-template-kwargs '{"enable_thinking": true}' \
  --speculative-algorithm DFLASH \
  --speculative-draft-model-path incoai/Qwen3.8-27B-DFlash2 \
  --speculative-num-draft-tokens 8 \
  --disable-overlap-schedule

source ../sh/vllm-docker-restart-service-install.sh
