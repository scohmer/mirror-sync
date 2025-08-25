#!/usr/bin/env bash
set -euo pipefail

echo "=== Debug Debian Script Step by Step ==="

# Exact same setup as debian-build-and-sync.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Fix for when running from project root - check if config exists in current dir
if [[ ! -f "$PROJECT_ROOT/config/mirror-sync.conf" && -f "$(pwd)/config/mirror-sync.conf" ]]; then
    PROJECT_ROOT="$(pwd)"
fi

echo "SCRIPT_DIR: $SCRIPT_DIR"
echo "PROJECT_ROOT: $PROJECT_ROOT"

# shellcheck source=../lib/common.sh
source "$PROJECT_ROOT/lib/common.sh"
load_config

# ---- Debian Specific Config ----
IMAGE="${DEBIAN_IMAGE:-debian-mirror:latest}"
CTX="${CTX:-./deb.debian.org}"
DEB_TARGET="${DEBIAN_TARGET:-/srv/mirrors/debian}"

# Mirror behavior (passed into container)
SUITES="${DEBIAN_SUITES:-bullseye bookworm trixie}"
ARCHS="${DEBIAN_ARCHS:-amd64,i386}"
THREADS="${DEFAULT_THREADS:-20}"
INCLUDE_SOURCES="${DEBIAN_INCLUDE_SOURCES:-true}"
INCLUDE_UPDATES="${DEBIAN_INCLUDE_UPDATES:-true}"
INCLUDE_BACKPORTS="${DEBIAN_INCLUDE_BACKPORTS:-true}"
METADATA_ONLY="${DEBIAN_METADATA_ONLY:-false}"

# Logging
LOG_DIR="${BASE_LOG_DIR:-/opt/mirror-sync/logs}/debian"
BUILD_LOG="$LOG_DIR/build.log"
RUN_LOG="$LOG_DIR/run.log"
LOCK_FILE="/var/lock/debian-mirror-sync.lock"

echo "Variables set up correctly"
echo "CTX: $CTX"
echo "Current directory: $(pwd)"
echo "Looking for context at: $(pwd)/$CTX"

# Check if context exists from current working directory
if [[ -d "$CTX" ]]; then
    echo "✓ Context directory found: $CTX"
else
    echo "✗ Context directory not found: $CTX"
    echo "Available directories:"
    ls -la . | head -10
    exit 1
fi

echo "=== Running Main Function Steps ==="
echo "Step 1: Starting log"
log_info "Starting Debian mirror sync"

echo "Step 2: Acquiring lock"
lock_or_exit "$LOCK_FILE" "debian-mirror-sync"

echo "Step 3: Network check"
wait_for_network

echo "Step 4: Setup logging"
setup_logging "$LOG_DIR" "debian"

echo "Step 5: Check disk space"
check_disk_space "$DEB_TARGET"

echo "Step 6: Build container (this is where it might hang)"
echo "About to call build_container_image with:"
echo "  IMAGE: $IMAGE"
echo "  CTX: $CTX"
echo "  BUILD_LOG: $BUILD_LOG"

if build_container_image "$IMAGE" "$CTX" "$BUILD_LOG"; then
    echo "✓ Container built successfully"
    
    echo "Step 7: Prepare target directory"
    prepare_target_directory "$DEB_TARGET"
    
    echo "✓ All steps completed - script should continue to container run"
    echo "Next step would be to run the sync container..."
    
else
    echo "✗ Container build failed"
    exit 1
fi

echo "=== Debug Complete ==="