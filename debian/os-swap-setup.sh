#!/bin/bash

echo "Setting Up Operating System ..."

SWAP_FILE="/swapfile"
SWAP_SIZE_GB=64

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root (e.g., sudo ./setup_swap.sh)"
  exit 1
fi

echo "Disabling existing swap..."
swapoff -a

echo "Allocating ${SWAP_SIZE_GB}GB to $SWAP_FILE..."
if ! fallocate -l "${SWAP_SIZE_GB}G" "$SWAP_FILE" 2>/dev/null; then
    echo "fallocate not supported on this filesystem. Falling back to dd..."
    dd if=/dev/zero of="$SWAP_FILE" bs=1G count="$SWAP_SIZE_GB" status=progress
fi

echo "Setting strict permissions..."
chmod 600 "$SWAP_FILE"

echo "Formatting swap space..."
mkswap "$SWAP_FILE"

echo "Enabling swap..."
swapon "$SWAP_FILE"

echo "Ensuring persistence in /etc/fstab..."
if ! grep -q "^$SWAP_FILE" /etc/fstab; then
    echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
    echo "Added $SWAP_FILE to /etc/fstab."
else
    echo "fstab entry already exists."
fi

echo "Done. Current memory and swap status:"
free -h


