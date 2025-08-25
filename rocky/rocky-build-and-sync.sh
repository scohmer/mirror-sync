#!/usr/bin/env bash
set -euo pipefail

# Load configuration and common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# shellcheck source=../lib/common.sh
source "$PROJECT_ROOT/lib/common.sh"
load_config

# ---- Rocky Linux Specific Config ----
IMAGE="${ROCKY_IMAGE:-rocky-mirror:latest}"
CTX="${CTX:-./dl.rockylinux.org}"
ROCKY_TARGET="${ROCKY_TARGET:-/srv/mirrors/rocky}"

# Mirror behavior (passed into container)
VERSIONS="${ROCKY_VERSIONS:-8 9 10}"
ARCHES="${ROCKY_ARCHES:-x86_64}"
REPOS="${ROCKY_REPOS:-AppStream BaseOS Devel Extras Plus PowerTools}"
UPSTREAM_BASE="${ROCKY_UPSTREAM_BASE:-https://dl.rockylinux.org/pub/rocky}"
KEEP_OLD="${ROCKY_KEEP_OLD:-false}"
NEWEST_ONLY="${ROCKY_NEWEST_ONLY:-true}"

# Logging
LOG_DIR="${BASE_LOG_DIR:-/opt/mirror-sync/logs}/rocky"
BUILD_LOG="$LOG_DIR/build.log"
RUN_LOG="$LOG_DIR/run.log"
LOCK_FILE="/var/lock/rocky-mirror-sync.lock"

# ========== Main Execution ==========
main() {
    log_info "Starting Rocky Linux mirror sync"
    
    # Acquire lock to prevent concurrent runs
    lock_or_exit "$LOCK_FILE" "rocky-mirror-sync"
    
    # Wait for network
    wait_for_network
    
    # Setup logging
    setup_logging "$LOG_DIR" "rocky"
    
    # Check disk space before starting
    check_disk_space "$ROCKY_TARGET"
    
    # Build container image
    if ! build_container_image "$IMAGE" "$CTX" "$BUILD_LOG"; then
        send_notification "Rocky Build Failed" "Container image build failed. See $BUILD_LOG"
        exit 1
    fi
    
    # Prepare target directory
    prepare_target_directory "$ROCKY_TARGET"
    
    log_info "Running Rocky Linux mirror sync..."
    log_debug "Versions: $VERSIONS | Arches: $ARCHES | Repos: $REPOS"
    
    # Run the sync container
    if ! run_container "$IMAGE" "rocky-mirror-sync" "$RUN_LOG" \
        -e "VERSIONS=$VERSIONS" \
        -e "ARCHES=$ARCHES" \
        -e "REPOS=$REPOS" \
        -e "UPSTREAM_BASE=$UPSTREAM_BASE" \
        -e "KEEP_OLD=$KEEP_OLD" \
        -e "NEWEST_ONLY=$NEWEST_ONLY" \
        -e "MIRROR_ROOT=$ROCKY_TARGET" \
        -v "$ROCKY_TARGET:$ROCKY_TARGET:Z"; then
        
        send_notification "Rocky Sync Failed" "Mirror synchronization failed. See $RUN_LOG"
        exit 1
    fi
    
    # Run health checks
    run_health_checks "$ROCKY_TARGET" "rocky"
    
    # Cleanup old images if enabled
    if [[ "${AUTO_CLEANUP_OLD_IMAGES:-true}" == "true" ]]; then
        cleanup_old_images "$IMAGE"
    fi
    
    # Cleanup old logs
    cleanup_old_logs "$LOG_DIR"
    
    log_info "Rocky Linux mirror sync completed successfully"
    log_info "Mirror available at: $ROCKY_TARGET"
    log_info "Logs: Build($BUILD_LOG) Run($RUN_LOG)"
    
    send_notification "Rocky Sync Complete" "Mirror synchronized successfully to $ROCKY_TARGET"
}

# Run main function
main "$@"
