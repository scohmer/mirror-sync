#!/usr/bin/env bash
set -euo pipefail

echo "=== Test build_container_image Function ==="

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
if [[ ! -f "$PROJECT_ROOT/config/mirror-sync.conf" && -f "$(pwd)/config/mirror-sync.conf" ]]; then
    PROJECT_ROOT="$(pwd)"
fi

source "$PROJECT_ROOT/lib/common.sh"
load_config

# Test parameters
IMAGE="debian-mirror:latest"
CTX="./apt-mirror/deb.debian.org"
LOG_DIR="/opt/mirror-sync/logs/debian"
BUILD_LOG="$LOG_DIR/build.log"

mkdir -p "$LOG_DIR"

echo "About to call build_container_image function..."
echo "Parameters: IMAGE=$IMAGE, CTX=$CTX, BUILD_LOG=$BUILD_LOG"

if build_container_image "$IMAGE" "$CTX" "$BUILD_LOG"; then
    echo "✓ build_container_image function succeeded"
    
    echo "Build log contents:"
    if [[ -f "$BUILD_LOG" ]]; then
        echo "--- Build log start ---"
        cat "$BUILD_LOG"
        echo "--- Build log end ---"
    else
        echo "No build log file created"
    fi
    
    echo "Available images:"
    podman images | grep -E "(debian-mirror|REPOSITORY)" || echo "No matching images found"
    
else
    echo "✗ build_container_image function failed"
    if [[ -f "$BUILD_LOG" ]]; then
        echo "Build log contents:"
        cat "$BUILD_LOG"
    fi
fi

echo "=== Test complete ==="