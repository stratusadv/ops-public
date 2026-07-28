#!/bin/bash

uv venv /root/vllm-venv

source /root/vllm-venv/bin/activate

uv pip install qwen-asr[vllm]
uv pip install vllm[audio]
uv pip install nvidia-cuda-runtime-cu12
uv pip install flashinfer-python --torch-backend=cu130
uv pip install -U vllm --pre \
  --extra-index-url https://wheels.vllm.ai/nightly/cu130 \
  --extra-index-url https://download.pytorch.org/whl/cu130 \
  --index-strategy unsafe-best-match

deactivate