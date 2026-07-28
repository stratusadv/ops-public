#!/bin/bash

uv venv /root/vllm-venv --python 3.12

source /root/vllm-venv/bin/activate

bash <(curl -fsSL https://raw.githubusercontent.com/vllm-project/vllm/main/tools/install_deepgemm.sh) --cuda-version 13.3

uv pip install qwen-asr[vllm]
uv pip install vllm[audio]
uv pip install -U vllm

deactivate