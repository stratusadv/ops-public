#!/bin/bash

# Main Configuration

export VLLM_ALLOW_LONG_MAX_MODEL_LEN=1

# Hardware Configuration

#export VLLM_SKIP_P2P_CHECK=1
#export NCCL_P2P_DISABLE=1
#export NCCL_CUMEM_ENABLE=0
#export NCCL_IB_DISABLE=1
#export VLLM_WORKER_MULTIPROC_METHOD=spawn
#export VLLM_USE_V1=0

# Use for debugging

#export NCCL_DEBUG=TRACE
#export VLLM_LOGGING_LEVEL=DEBUG

source /root/vllm-venv/bin/activate

#vllm serve --config /root/vllm-config.yml --trust-remote-code --disable-custom-all-reduce --enable-prefix-caching --enable-chunked-prefill
vllm serve --config /root/vllm-config.yml --trust-remote-code --enable-prefix-caching --enable-chunked-prefill

deactivate