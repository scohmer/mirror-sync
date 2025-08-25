#!/usr/bin/env bash
set -euo pipefail

echo "=== Minimal Main Function Debug ==="
echo "This replicates the exact main() function from debian-build-and-sync.sh"
echo

# Exact same setup as debian script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [[ ! -f "$PROJECT_ROOT/config/mirror-sync.conf" && -f "$(pwd)/config/mirror-sync.conf" ]]; then
    PROJECT_ROOT="$(pwd)"
fi

source "$PROJECT_ROOT/lib/common.sh"
load_config

# Same variables
IMAGE="${DEBIAN_IMAGE:-debian-mirror:latest}"
CTX="${CTX:-./apt-mirror/deb.debian.org}"
DEB_TARGET="${DEBIAN_TARGET:-/srv/mirrors/debian}"
SUITES="${DEBIAN_SUITES:-bullseye bookworm trixie}"
ARCHS="${DEBIAN_ARCHS:-amd64,i386}"
THREADS="${DEFAULT_THREADS:-20}"
INCLUDE_SOURCES="${DEBIAN_INCLUDE_SOURCES:-true}"
INCLUDE_UPDATES="${DEBIAN_INCLUDE_UPDATES:-true}"
INCLUDE_BACKPORTS="${DEBIAN_INCLUDE_BACKPORTS:-true}"
METADATA_ONLY="${DEBIAN_METADATA_ONLY:-false}"

LOG_DIR="${BASE_LOG_DIR:-/opt/mirror-sync/logs}/debian"
BUILD_LOG="$LOG_DIR/build.log"
RUN_LOG="$LOG_DIR/run.log"
LOCK_FILE="/var/lock/debian-mirror-sync.lock"

echo "All variables set. Starting main function replication..."

# Replicate exact main() function with debugging
main() {
    echo "MAIN: Starting log_info"
    log_info "Starting Debian mirror sync"
    
    echo "MAIN: Calling lock_or_exit"
    lock_or_exit "$LOCK_FILE" "debian-mirror-sync"
    
    echo "MAIN: Calling wait_for_network"
    wait_for_network
    
    echo "MAIN: Calling setup_logging"
    setup_logging "$LOG_DIR" "debian"
    
    echo "MAIN: Calling check_disk_space"
    check_disk_space "$DEB_TARGET"
    
    echo "MAIN: About to call build_container_image - this is likely where it hangs"
    echo "MAIN: Parameters - IMAGE: $IMAGE, CTX: $CTX, BUILD_LOG: $BUILD_LOG"
    
    if ! build_container_image "$IMAGE" "$CTX" "$BUILD_LOG"; then
        echo "MAIN: build_container_image FAILED"
        send_notification "Debian Build Failed" "Container image build failed. See $BUILD_LOG"
        exit 1
    fi
    
    echo "MAIN: build_container_image completed successfully"
    echo "MAIN: Calling prepare_target_directory"
    prepare_target_directory "$DEB_TARGET"
    
    echo "MAIN: All setup steps completed - would continue with container run"
    echo "MAIN: This proves the script logic works"
}

echo "About to call main function..."
main
echo "✓ Main function completed successfully!"