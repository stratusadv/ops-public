#!/bin/bash
# Enable persistence mode (required to maintain power settings)
nvidia-smi -pm 1
# Set the power limit to 350 Watts
nvidia-smi -pl 350