#!/usr/bin/env bash
set -euo pipefail

echo "=== Simple Main Function Test ==="

# Same setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [[ ! -f "$PROJECT_ROOT/config/mirror-sync.conf" && -f "$(pwd)/config/mirror-sync.conf" ]]; then
    PROJECT_ROOT="$(pwd)"
fi

source "$PROJECT_ROOT/lib/common.sh"
load_config

# Same variables as debian script
IMAGE="debian-mirror:latest"
CTX="./apt-mirror/deb.debian.org"
DEB_TARGET="/srv/mirrors/debian"
LOG_DIR="/opt/mirror-sync/logs/debian"
BUILD_LOG="$LOG_DIR/build.log"
LOCK_FILE="/var/lock/debian-mirror-sync.lock"

# Simplified main function
simple_main() {
    echo "SIMPLE MAIN: Starting..."
    log_info "Starting Debian mirror sync"
    
    echo "SIMPLE MAIN: Lock..."
    lock_or_exit "$LOCK_FILE" "debian-mirror-sync"
    
    echo "SIMPLE MAIN: Network..."
    wait_for_network
    
    echo "SIMPLE MAIN: Logging..."
    setup_logging "$LOG_DIR" "debian"
    
    echo "SIMPLE MAIN: Disk space..."
    check_disk_space "$DEB_TARGET"
    
    echo "SIMPLE MAIN: Build..."
    build_container_image "$IMAGE" "$CTX" "$BUILD_LOG"
    
    echo "SIMPLE MAIN: All steps completed!"
}

echo "About to call simple_main..."
simple_main
echo "simple_main returned successfully!"