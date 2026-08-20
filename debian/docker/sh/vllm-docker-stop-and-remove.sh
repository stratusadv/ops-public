#!/bin/bash

echo "Stopping VLLM Docker and Removing Container"

docker stop vllm

docker container rm vllm