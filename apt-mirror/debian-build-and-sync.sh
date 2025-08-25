#!/usr/bin/env bash
set -euo pipefail

# Load configuration and common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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

# ========== Main Execution ==========
main() {
    log_info "Starting Debian mirror sync"
    
    # Acquire lock to prevent concurrent runs
    lock_or_exit "$LOCK_FILE" "debian-mirror-sync"
    
    # Wait for network
    wait_for_network
    
    # Setup logging
    setup_logging "$LOG_DIR" "debian"
    
    # Check disk space before starting
    check_disk_space "$DEB_TARGET"
    
    # Build container image
    if ! build_container_image "$IMAGE" "$CTX" "$BUILD_LOG"; then
        send_notification "Debian Build Failed" "Container image build failed. See $BUILD_LOG"
        exit 1
    fi
    
    # Prepare target directory
    prepare_target_directory "$DEB_TARGET"
    
    log_info "Running Debian mirror sync..."
    log_debug "Suites: $SUITES | Archs: $ARCHS | Threads: $THREADS"
    
    # Run the sync container
    if ! run_container "$IMAGE" "debian-apt-mirror" "$RUN_LOG" \
        -e "SUITES=$SUITES" \
        -e "ARCHS=$ARCHS" \
        -e "THREADS=$THREADS" \
        -e "INCLUDE_SOURCES=$INCLUDE_SOURCES" \
        -e "INCLUDE_UPDATES=$INCLUDE_UPDATES" \
        -e "INCLUDE_BACKPORTS=$INCLUDE_BACKPORTS" \
        -e "METADATA_ONLY=$METADATA_ONLY" \
        -e "MIRROR_ROOT=$DEB_TARGET" \
        -v "$DEB_TARGET:$DEB_TARGET:Z" \
        --entrypoint /usr/local/bin/sync-debian-mirror.sh; then
        
        send_notification "Debian Sync Failed" "Mirror synchronization failed. See $RUN_LOG"
        exit 1
    fi
    
    # Run health checks
    run_health_checks "$DEB_TARGET" "debian"
    
    # Cleanup old images if enabled
    if [[ "${AUTO_CLEANUP_OLD_IMAGES:-true}" == "true" ]]; then
        cleanup_old_images "$IMAGE"
    fi
    
    # Cleanup old logs
    cleanup_old_logs "$LOG_DIR"
    
    log_info "Debian mirror sync completed successfully"
    log_info "Mirror available at: $DEB_TARGET"
    log_info "Logs: Build($BUILD_LOG) Run($RUN_LOG)"
    
    send_notification "Debian Sync Complete" "Mirror synchronized successfully to $DEB_TARGET"
}

# Run main function
main "$@"
