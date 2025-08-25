#!/usr/bin/env bash
set -euo pipefail

echo "=== Debug Build Container Image ==="
echo "Date: $(date)"

# Setup same as debian script
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

echo "=== Testing build_container_image Function ==="
echo "IMAGE: $IMAGE"
echo "CTX: $CTX"
echo "BUILD_LOG: $BUILD_LOG"

# Check container runtime
runtime="$(get_container_runtime)"
echo "Container runtime: $runtime"
echo "Runtime version: $($runtime --version)"

# Test if we can run basic podman commands
echo "Testing basic container commands..."
if $runtime info >/dev/null 2>&1; then
    echo "✓ Container runtime info command works"
else
    echo "✗ Container runtime info command failed"
fi

# Check the context directory
echo "Context directory contents:"
ls -la "$CTX"

# Try to build manually (with verbose output)
echo "=== Manual Build Test ==="
echo "Running: $runtime build -t '$IMAGE' '$CTX'"

# Capture start time
start_time=$(date)
echo "Build started at: $start_time"

# Run the build command with timeout to prevent hanging
if timeout 300 "$runtime" build -t "$IMAGE" "$CTX"; then
    echo "✓ Manual build succeeded"
    echo "Build completed at: $(date)"
    
    # Check if image was created
    if "$runtime" images | grep -q "$IMAGE"; then
        echo "✓ Image '$IMAGE' exists in container registry"
    else
        echo "✗ Image '$IMAGE' not found in container registry"
    fi
else
    build_exit_code=$?
    echo "✗ Manual build failed or timed out (exit code: $build_exit_code)"
    echo "Build ended at: $(date)"
fi

echo "=== Debug Complete ==="