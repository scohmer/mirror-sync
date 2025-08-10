#!/usr/bin/env bash
set -euo pipefail

DEB_IMAGE_NAME="debian-mirror:bullseye"
SEC_IMAGE_NAME="security-mirror:bullseye"

DEB_CTX="./deb.debian.org"
SEC_CTX="./security.debian.org"

DEB_MIRROR_DIR="/srv/apt/debian/deb.debian.org/debian"
SEC_MIRROR_DIR="/srv/apt/debian/security.debian.org/debian-security"

LOG_DIR="${LOG_DIR:-/opt/mirror-sync/debian/log}"
mkdir -p "$LOG_DIR"

echo "[*] Building images in parallel…"
podman build -t "$DEB_IMAGE_NAME" "$DEB_CTX" >"$LOG_DIR/build-deb.log" 2>&1 &
PID_BUILD_DEB=$!
podman build -t "$SEC_IMAGE_NAME" "$SEC_CTX" >"$LOG_DIR/build-sec.log" 2>&1 &
PID_BUILD_SEC=$!

# Wait for both builds
wait "$PID_BUILD_DEB"
echo "[✓] Built $DEB_IMAGE_NAME (log: $LOG_DIR/build-deb.log)"
wait "$PID_BUILD_SEC"
echo "[✓] Built $SEC_IMAGE_NAME (log: $LOG_DIR/build-sec.log)"

# Prep dirs (can be serial; quick and avoids SELinux races)
sudo mkdir -p "$DEB_MIRROR_DIR" "$SEC_MIRROR_DIR"
sudo chown -R root:root "$DEB_MIRROR_DIR" "$SEC_MIRROR_DIR"
# SELinux context for container volumes
sudo chcon -Rt container_file_t "$DEB_MIRROR_DIR" "$SEC_MIRROR_DIR" || true

echo "[*] Running both sync containers in parallel…"
podman run --rm -v "$DEB_MIRROR_DIR:/debian-mirror:Z" "$DEB_IMAGE_NAME" >"$LOG_DIR/run-deb.log" 2>&1 &
PID_RUN_DEB=$!

podman run --rm -v "$SEC_MIRROR_DIR:/debian-mirror:Z" "$SEC_IMAGE_NAME" >"$LOG_DIR/run-sec.log" 2>&1 &
PID_RUN_SEC=$!

# Wait for both runs
FAIL=0
wait "$PID_RUN_DEB" || { echo "[!] Debian mirror container failed. See $LOG_DIR/run-deb.log"; FAIL=1; }
wait "$PID_RUN_SEC" || { echo "[!] Security mirror container failed. See $LOG_DIR/run-sec.log"; FAIL=1; }

if [[ $FAIL -eq 0 ]]; then
  echo "[✓] Debian mirror sync complete at: $DEB_MIRROR_DIR"
  echo "[✓] Security mirror sync complete at: $SEC_MIRROR_DIR"
  echo "Logs: $LOG_DIR/run-deb.log, $LOG_DIR/run-sec.log"
  exit 0
else
  echo "[x] One or more syncs failed. Check logs above."
  exit 1
fi
