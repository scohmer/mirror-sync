#!/usr/bin/env bash
set -euo pipefail

IMAGE="debian-mirror:latest"
CTX="./deb.debian.org"
DEB_TARGET="/srv/apt/debian/deb.debian.org/debian"
SEC_TARGET="/srv/apt/debian/security.debian.org/debian-security"
LOG_DIR="${LOG_DIR:-/opt/mirror-sync/debian/log}"
mkdir -p "$LOG_DIR"

echo "[*] Building image..."
podman build -t "$IMAGE" "$CTX" >"$LOG_DIR/build.log" 2>&1
echo "[✓] Built $IMAGE (log: $LOG_DIR/build.log)"

echo "[*] Preparing targets..."
sudo mkdir -p "$DEB_TARGET"
sudo chown root:root "$DEB_TARGET"
# SELinux: relabel for podman so the container can write
sudo chcon -Rt container_file_t "$DEB_TARGET" || true

sudo mkdir -p "$SEC_TARGET"
sudo chown root:root "$SEC_TARGET"
# SELinux: relabel for podman so the container can write
sudo chcon -Rt container_file_t "$SEC_TARGET" || true

echo "[*] Running sync..."
podman run --rm --name debian-mirror \
  -v "$DEB_TARGET:/debian-mirror:Z" \
  -v "$SEC_TARGET:/security-mirror:Z" \
  --entrypoint /usr/local/bin/sync-debian-mirror.sh \
  "$IMAGE" >"$LOG_DIR/run.log" 2>&1 || { 
    echo "[x] Sync failed. See $LOG_DIR/run.log"; exit 1; 
  }

echo "[✓] Sync complete at: $TARGET"
echo "Log: $LOG_DIR/run.log"
