#!/bin/bash
set -e

# Define names
IMAGE_NAME=debian-mirror:bookworm
MIRROR_DIR=/srv/debian-mirror

# Build the container image
echo "[*] Building container image..."
podman build -t "$IMAGE_NAME" .

# Ensure mirror directory exists
sudo mkdir -p "$MIRROR_DIR"
sudo chown -R root:root "$MIRROR_DIR"
sudo chcon -Rt container_file_t "$MIRROR_DIR"  # Needed for SELinux

# Run the container to sync the mirror
echo "[*] Running container to sync mirror..."
podman run --rm -v "$MIRROR_DIR":/debian-mirror:Z "$IMAGE_NAME"

echo "[✓] Mirror sync complete at: $MIRROR_DIR"

