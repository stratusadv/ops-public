#!/bin/bash

echo "Stopping Speakers Docker and Removing Container"

docker stop speakers

docker container rm speakers
