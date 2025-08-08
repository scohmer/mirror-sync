#!/bin/bash
set -e

# Define names
DEB_IMAGE_NAME=debian-11-mirror:bullseye
SEC_IMAGE_NAME=security-11-mirror:bullseye
DEB_MIRROR_DIR=/srv/apt/debian/deb.debian.org/debian
SEC_MIRROR_DIR=/srv/apt/debian/security.debian.org/debian-security

# Processes related to Debian 11 mirror synchronization
# Build the container image
echo "[*] Building container image..."
podman build -t "$DEB_IMAGE_NAME" .

# Ensure mirror directory exists
sudo mkdir -p "$DEB_MIRROR_DIR"
sudo chown -R root:root "$DEB_MIRROR_DIR"
sudo chcon -Rt container_file_t "$DEB_MIRROR_DIR"  # Needed for SELinux

# Run the container to sync the mirror
echo "[*] Running container to sync mirror..."
podman run --rm -v "$DEB_MIRROR_DIR":/debian-mirror:Z "$DEB_IMAGE_NAME"

echo "[✓] Debian mirror sync complete at: $DEB_MIRROR_DIR"

# Processes related to Debian 11 security mirror synchronization
# Build the container image
echo "[*] Building container image..."
podman build -t "$SEC_IMAGE_NAME" .

# Ensure mirror directory exists
sudo mkdir -p "$SEC_MIRROR_DIR"
sudo chown -R root:root "$SEC_MIRROR_DIR"
sudo chcon -Rt container_file_t "$SEC_MIRROR_DIR"  # Needed for SELinux

# Run the container to sync the mirror
echo "[*] Running container to sync mirror..."
podman run --rm -v "$SEC_MIRROR_DIR":/debian-mirror:Z "$SEC_IMAGE_NAME""

echo "[✓] Security mirror sync complete at: $SEC_MIRROR_DIR"

