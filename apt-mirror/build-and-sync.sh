#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-debian-mirror:latest}"
CTX="${CTX:-./deb.debian.org}"

# Single root for everything apt-mirror writes (main + security)
# Use the new, shorter path you picked earlier
DEB_TARGET="${DEB_TARGET:-/srv/apt/apt-mirror}"

LOG_DIR="${LOG_DIR:-/opt/mirror-sync/apt-mirror/log}"
mkdir -p "$LOG_DIR"

echo "[*] Building image..."
podman build -t "$IMAGE" "$CTX" >"$LOG_DIR/build.log" 2>&1
echo "[✓] Built $IMAGE (log: $LOG_DIR/build.log)"

echo "[*] Preparing target..."
sudo mkdir -p "$DEB_TARGET"
sudo chown root:root "$DEB_TARGET"
# SELinux: either keep this chcon and drop :Z below, or remove this and keep :Z.
sudo chcon -Rt container_file_t "$DEB_TARGET" || true

echo "[*] Running sync via apt-mirror..."
# Env vars consumed by /usr/local/bin/sync-debian-mirror.sh in the container
# Defaults: Debian 11/12/13, amd64, FULL mirror for disconnected use
podman run --rm --name debian-apt-mirror \
  -e SUITES="${SUITES:-bullseye bookworm trixie}" \
  -e ARCHS="${ARCHS:-amd64}" \
  -e THREADS="${THREADS:-20}" \
  -e INCLUDE_UPDATES="${INCLUDE_UPDATES:-true}" \
  -e INCLUDE_BACKPORTS="${INCLUDE_BACKPORTS:-true}" \
  -e METADATA_ONLY="${METADATA_ONLY:-false}" \
  -e MIRROR_ROOT="$DEB_TARGET" \
  -v "$DEB_TARGET:$DEB_TARGET" \   # no :Z since we ran chcon above
  --entrypoint /usr/local/bin/sync-debian-mirror.sh \
  "$IMAGE" >"$LOG_DIR/run.log" 2>&1 || {
    echo "[x] Sync failed. See $LOG_DIR/run.log"; exit 1;
  }

echo "[✓] Sync complete at: $DEB_TARGET"
echo "Log: $LOG_DIR/run.log"
