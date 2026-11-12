#!/bin/bash

echo "Stopping Embed Docker and Removing Container"

docker stop embed

docker container rm embed
