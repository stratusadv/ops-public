#!/bin/bash

uv venv /root/vllm-venv --python 3.12

source /root/vllm-venv/bin/activate

uv pip install qwen-asr[vllm]
uv pip install vllm[audio]
uv pip install -U vllm

deactivate