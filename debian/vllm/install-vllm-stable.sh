#!/bin/bash

./sh/environment-setup.sh &&
./sh/vllm-stable-install.sh &&
./sh/vllm-service-install.sh

echo "Stable Vllm Install ✅ Done"