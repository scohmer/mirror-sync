#!/usr/bin/env bash
set -euo pipefail

# ---- Config (override via env) ----
IMAGE="${IMAGE:-debian-mirror:latest}"
CTX="${CTX:-./deb.debian.org}"                  # directory containing your Containerfile
DEB_TARGET="${DEB_TARGET:-/srv/apt/debian}" # host directory to store the mirror

# Mirror behavior (passed into the container entrypoint)
SUITES="${SUITES:-bullseye bookworm trixie}"    # Debian 11/12/13
ARCHS="${ARCHS:-amd64}"
THREADS="${THREADS:-20}"
INCLUDE_UPDATES="${INCLUDE_UPDATES:-true}"
INCLUDE_BACKPORTS="${INCLUDE_BACKPORTS:-true}"
METADATA_ONLY="${METADATA_ONLY:-false}"         # disconnected mirror => keep packages by default

# Logging
LOG_DIR="${LOG_DIR:-/opt/mirror-sync/apt-mirror/log}"
mkdir -p "$LOG_DIR"

echo "[*] Building image..."
podman build -t "$IMAGE" "$CTX" >"$LOG_DIR/build.log" 2>&1
echo "[✓] Built $IMAGE (log: $LOG_DIR/build.log)"

echo "[*] Preparing target..."
sudo mkdir -p "$DEB_TARGET"
sudo chown root:root "$DEB_TARGET"

# If your host uses SELinux, EITHER keep :Z on the volume OR run chcon once.
# We'll keep :Z on the volume to avoid permanent relabeling here.
# sudo chcon -Rt container_file_t "$DEB_TARGET" || true

echo "[*] Running sync via apt-mirror..."
# The container must have /usr/local/bin/sync-debian-mirror.sh as provided earlier.
if ! podman run --rm --name debian-apt-mirror \
  -e SUITES="$SUITES" \
  -e ARCHS="$ARCHS" \
  -e THREADS="$THREADS" \
  -e INCLUDE_UPDATES="$INCLUDE_UPDATES" \
  -e INCLUDE_BACKPORTS="$INCLUDE_BACKPORTS" \
  -e METADATA_ONLY="$METADATA_ONLY" \
  -e MIRROR_ROOT="$DEB_TARGET" \
  -v "$DEB_TARGET:$DEB_TARGET:Z" \
  --entrypoint /usr/local/bin/sync-debian-mirror.sh \
  "$IMAGE" >"$LOG_DIR/run.log" 2>&1
then
  echo "[x] Sync failed. See $LOG_DIR/run.log"
  exit 1
fi

echo "[✓] Sync complete at: $DEB_TARGET"
echo "Log: $LOG_DIR/run.log"
