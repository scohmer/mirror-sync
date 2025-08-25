#!/usr/bin/env bash
set -euo pipefail

echo "=== Debug Debian Sync ==="
echo "Date: $(date)"
echo "PWD: $(pwd)"

# Load configuration and common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Fix for when running from project root - check if config exists in current dir
if [[ ! -f "$PROJECT_ROOT/config/mirror-sync.conf" && -f "$(pwd)/config/mirror-sync.conf" ]]; then
    PROJECT_ROOT="$(pwd)"
fi

echo "PROJECT_ROOT: $PROJECT_ROOT"

# shellcheck source=lib/common.sh
source "$PROJECT_ROOT/lib/common.sh"
echo "✓ Sourced common.sh"

load_config
echo "✓ Loaded configuration"

# ---- Debian Specific Config ----
IMAGE="${DEBIAN_IMAGE:-debian-mirror:latest}"
CTX="${CTX:-./apt-mirror/deb.debian.org}"
DEB_TARGET="${DEBIAN_TARGET:-/srv/mirrors/debian}"

echo "IMAGE: $IMAGE"
echo "CTX: $CTX" 
echo "DEB_TARGET: $DEB_TARGET"

# Mirror behavior (passed into container)
SUITES="${DEBIAN_SUITES:-bullseye bookworm trixie}"
ARCHS="${DEBIAN_ARCHS:-amd64,i386}"
THREADS="${DEFAULT_THREADS:-20}"
INCLUDE_SOURCES="${DEBIAN_INCLUDE_SOURCES:-true}"
INCLUDE_UPDATES="${DEBIAN_INCLUDE_UPDATES:-true}"
INCLUDE_BACKPORTS="${DEBIAN_INCLUDE_BACKPORTS:-true}"
METADATA_ONLY="${DEBIAN_METADATA_ONLY:-false}"

echo "SUITES: $SUITES"
echo "ARCHS: $ARCHS"

# Logging
LOG_DIR="${BASE_LOG_DIR:-/opt/mirror-sync/logs}/debian"
BUILD_LOG="$LOG_DIR/build.log"
RUN_LOG="$LOG_DIR/run.log"
LOCK_FILE="/var/lock/debian-mirror-sync.lock"

echo "LOG_DIR: $LOG_DIR"
echo "BUILD_LOG: $BUILD_LOG"
echo "RUN_LOG: $RUN_LOG"
echo "LOCK_FILE: $LOCK_FILE"

# Test each step individually
echo "=== Testing Individual Steps ==="

echo "Step 1: log_info test"
log_info "Starting Debian mirror sync"

echo "Step 2: lock_or_exit test"
lock_or_exit "$LOCK_FILE" "debian-mirror-sync"
echo "✓ Lock acquired"

echo "Step 3: wait_for_network test"
wait_for_network
echo "✓ Network confirmed"

echo "Step 4: setup_logging test"
setup_logging "$LOG_DIR" "debian"
echo "✓ Logging setup complete"
echo "Checking if log files exist now:"
ls -la "$LOG_DIR/" || echo "Log directory is empty"

echo "Step 5: check_disk_space test"
if check_disk_space "$DEB_TARGET"; then
    echo "✓ Disk space check passed"
else
    echo "⚠ Disk space check returned warning"
fi

echo "Step 6: Container context check"
if [[ -d "$CTX" ]]; then
    echo "✓ Container context directory exists: $CTX"
    ls -la "$CTX/"
else
    echo "✗ Container context directory missing: $CTX"
    echo "Available directories in apt-mirror/:"
    ls -la apt-mirror/ || echo "apt-mirror directory not found"
fi

echo "Step 7: build_container_image test (dry run)"
echo "Would call: build_container_image \"$IMAGE\" \"$CTX\" \"$BUILD_LOG\""
runtime="$(get_container_runtime)"
echo "Container runtime: $runtime"

echo "=== Debug Complete ==="
echo "If all steps passed, the issue is likely in the build_container_image function."