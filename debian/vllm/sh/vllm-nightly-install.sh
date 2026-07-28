#!/bin/bash

uv venv /root/vllm-venv

source /root/vllm-venv/bin/activate

bash <(curl -fsSL https://raw.githubusercontent.com/vllm-project/vllm/main/tools/install_deepgemm.sh) --cuda-version 13.3

uv pip install qwen-asr[vllm]
uv pip install vllm[audio]
uv pip install nvidia-cuda-runtime-cu12
uv pip install flashinfer-python --torch-backend=cu130
uv pip install -U vllm --pre \
  --extra-index-url https://wheels.vllm.ai/nightly/cu130 \
  --extra-index-url https://download.pytorch.org/whl/cu130 \
  --index-strategy unsafe-best-match

deactivate