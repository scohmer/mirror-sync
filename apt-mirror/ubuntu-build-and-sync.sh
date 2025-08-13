#!/usr/bin/env bash
set -euo pipefail

# ---- Config (override via env) ----
IMAGE="${IMAGE:-ubuntu-mirror:latest}"
CTX="${CTX:-./archive.ubuntu.com}"                  # directory containing your Containerfile
UBU_TARGET="${UBU_TARGET:-/srv/apt/ubuntu/archive.ubuntu.com/ubuntu}"  # host directory to store the mirror

# Mirror behavior (passed into the container entrypoint)
UBUNTU_VERSIONS="${UBUNTU_VERSIONS:-20.04 22.04 24.04 25.04}"
ARCHS="${ARCHS:-amd64,i386}"
THREADS="${THREADS:-20}"
INCLUDE_SOURCES="${INCLUDE_SOURCES:-true}"
INCLUDE_UPDATES="${INCLUDE_UPDATES:-true}"
INCLUDE_BACKPORTS="${INCLUDE_BACKPORTS:-true}"
METADATA_ONLY="${METADATA_ONLY:-false}"

# Optional: override upstream mirrors used by the script
UBUNTU_MIRROR="${UBUNTU_MIRROR:-http://archive.ubuntu.com/ubuntu}"
UBUNTU_SECURITY_MIRROR="${UBUNTU_SECURITY_MIRROR:-http://security.ubuntu.com/ubuntu}"

# Logging
LOG_DIR="${LOG_DIR:-/opt/mirror-sync/apt-mirror/log}"
mkdir -p "$LOG_DIR"

echo "[*] Building image from $CTX..."
podman build -t "$IMAGE" "$CTX" >"$LOG_DIR/build.log" 2>&1
echo "[✓] Built $IMAGE (log: $LOG_DIR/build.log)"

echo "[*] Preparing target at $UBU_TARGET..."
sudo mkdir -p "$UBU_TARGET"
sudo chown root:root "$UBU_TARGET"

# If your host uses SELinux, keep :Z on the volume (or chcon once instead).
# sudo chcon -Rt container_file_t "$UBU_TARGET" || true

echo "[*] Running Ubuntu mirror sync via apt-mirror..."
# The image must contain /usr/local/bin/sync-ubuntu-mirror.sh as entrypoint script.
if ! podman run --rm --name ubuntu-apt-mirror \
  -e UBUNTU_VERSIONS="$UBUNTU_VERSIONS" \
  -e ARCHS="$ARCHS" \
  -e THREADS="$THREADS" \
  -e INCLUDE_SOURCES="$INCLUDE_SOURCES" \
  -e INCLUDE_UPDATES="$INCLUDE_UPDATES" \
  -e INCLUDE_BACKPORTS="$INCLUDE_BACKPORTS" \
  -e METADATA_ONLY="$METADATA_ONLY" \
  -e UBUNTU_MIRROR="$UBUNTU_MIRROR" \
  -e UBUNTU_SECURITY_MIRROR="$UBUNTU_SECURITY_MIRROR" \
  -e MIRROR_ROOT="$UBU_TARGET" \
  -v "$UBU_TARGET:$UBU_TARGET:Z" \
  --entrypoint /usr/local/bin/sync-ubuntu-mirror.sh \
  "$IMAGE" >"$LOG_DIR/run.log" 2>&1
then
  echo "[x] Sync failed. See $LOG_DIR/run.log"
  exit 1
fi

echo "[✓] Sync complete at: $UBU_TARGET"
echo "Log: $LOG_DIR/run.log"
