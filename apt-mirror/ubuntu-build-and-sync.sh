#!/usr/bin/env bash
set -euo pipefail

# Load configuration and common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# shellcheck source=../lib/common.sh
source "$PROJECT_ROOT/lib/common.sh"
load_config

# ---- Ubuntu Specific Config ----
IMAGE="${UBUNTU_IMAGE:-ubuntu-mirror:latest}"
CTX="${CTX:-./archive.ubuntu.com}"
UBU_TARGET="${UBUNTU_TARGET:-/srv/mirrors/ubuntu}"

# Mirror behavior (passed into container)
UBUNTU_VERSIONS="${UBUNTU_VERSIONS:-20.04 22.04 24.04 25.04}"
ARCHS="${UBUNTU_ARCHS:-amd64,i386}"
THREADS="${DEFAULT_THREADS:-20}"
INCLUDE_SOURCES="${UBUNTU_INCLUDE_SOURCES:-true}"
INCLUDE_UPDATES="${UBUNTU_INCLUDE_UPDATES:-true}"
INCLUDE_BACKPORTS="${UBUNTU_INCLUDE_BACKPORTS:-true}"
METADATA_ONLY="${UBUNTU_METADATA_ONLY:-false}"

# Upstream mirrors
UBUNTU_MIRROR="${UBUNTU_MIRROR:-http://archive.ubuntu.com/ubuntu}"
UBUNTU_SECURITY_MIRROR="${UBUNTU_SECURITY_MIRROR:-http://security.ubuntu.com/ubuntu}"

# Logging
LOG_DIR="${BASE_LOG_DIR:-/opt/mirror-sync/logs}/ubuntu"
BUILD_LOG="$LOG_DIR/build.log"
RUN_LOG="$LOG_DIR/run.log"
LOCK_FILE="/var/lock/ubuntu-mirror-sync.lock"

# ========== Main Execution ==========
main() {
    log_info "Starting Ubuntu mirror sync"
    
    # Acquire lock to prevent concurrent runs
    lock_or_exit "$LOCK_FILE" "ubuntu-mirror-sync"
    
    # Wait for network
    wait_for_network
    
    # Setup logging
    setup_logging "$LOG_DIR" "ubuntu"
    
    # Check disk space before starting
    check_disk_space "$UBU_TARGET"
    
    # Build container image
    if ! build_container_image "$IMAGE" "$CTX" "$BUILD_LOG"; then
        send_notification "Ubuntu Build Failed" "Container image build failed. See $BUILD_LOG"
        exit 1
    fi
    
    # Prepare target directory
    prepare_target_directory "$UBU_TARGET"
    
    log_info "Running Ubuntu mirror sync..."
    log_debug "Versions: $UBUNTU_VERSIONS | Archs: $ARCHS | Threads: $THREADS"
    
    # Run the sync container
    if ! run_container "$IMAGE" "ubuntu-apt-mirror" "$RUN_LOG" \
        -e "UBUNTU_VERSIONS=$UBUNTU_VERSIONS" \
        -e "ARCHS=$ARCHS" \
        -e "THREADS=$THREADS" \
        -e "INCLUDE_SOURCES=$INCLUDE_SOURCES" \
        -e "INCLUDE_UPDATES=$INCLUDE_UPDATES" \
        -e "INCLUDE_BACKPORTS=$INCLUDE_BACKPORTS" \
        -e "METADATA_ONLY=$METADATA_ONLY" \
        -e "UBUNTU_MIRROR=$UBUNTU_MIRROR" \
        -e "UBUNTU_SECURITY_MIRROR=$UBUNTU_SECURITY_MIRROR" \
        -e "MIRROR_ROOT=$UBU_TARGET" \
        -v "$UBU_TARGET:$UBU_TARGET:Z" \
        --entrypoint /usr/local/bin/sync-ubuntu-mirror.sh; then
        
        send_notification "Ubuntu Sync Failed" "Mirror synchronization failed. See $RUN_LOG"
        exit 1
    fi
    
    # Run health checks
    run_health_checks "$UBU_TARGET" "ubuntu"
    
    # Cleanup old images if enabled
    if [[ "${AUTO_CLEANUP_OLD_IMAGES:-true}" == "true" ]]; then
        cleanup_old_images "$IMAGE"
    fi
    
    # Cleanup old logs
    cleanup_old_logs "$LOG_DIR"
    
    log_info "Ubuntu mirror sync completed successfully"
    log_info "Mirror available at: $UBU_TARGET"
    log_info "Logs: Build($BUILD_LOG) Run($RUN_LOG)"
    
    send_notification "Ubuntu Sync Complete" "Mirror synchronized successfully to $UBU_TARGET"
}

# Run main function
main "$@"
