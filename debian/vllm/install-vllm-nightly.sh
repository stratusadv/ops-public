#!/bin/bash

./sh/environment-setup.sh &&
./sh/vllm-nightly-install.sh &&
./sh/vllm-service-install.sh

echo "Nightly Vllm Install ✅ Done"