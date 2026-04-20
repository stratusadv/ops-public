#!/bin/bash

echo "Setting Nvidia GPU Power Limit ..."

nvidia-smi -pm 1

echo "Power limit set to 350watts"
nvidia-smi -pl 350

echo "✅ Done"