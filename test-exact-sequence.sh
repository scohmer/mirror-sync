#!/usr/bin/env bash
set -euo pipefail

echo "=== Test Exact Sequence from Main ==="

# Exact same setup as main function
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [[ ! -f "$PROJECT_ROOT/config/mirror-sync.conf" && -f "$(pwd)/config/mirror-sync.conf" ]]; then
    PROJECT_ROOT="$(pwd)"
fi

source "$PROJECT_ROOT/lib/common.sh"
load_config

# Same variables
DEB_TARGET="${DEBIAN_TARGET:-/srv/mirrors/debian}"
LOG_DIR="${BASE_LOG_DIR:-/opt/mirror-sync/logs}/debian"
LOCK_FILE="/var/lock/debian-mirror-sync.lock"

echo "Variables loaded. Testing each function call individually..."

echo "1. Testing log_info..."
log_info "Starting Debian mirror sync"
echo "✓ log_info completed"

echo "2. Testing lock_or_exit..."
lock_or_exit "$LOCK_FILE" "debian-mirror-sync"
echo "✓ lock_or_exit completed"

echo "3. Testing wait_for_network..."
wait_for_network
echo "✓ wait_for_network completed"

echo "4. Testing setup_logging..."
setup_logging "$LOG_DIR" "debian"
echo "✓ setup_logging completed"

echo "5. Testing check_disk_space..."
echo "About to call: check_disk_space \"$DEB_TARGET\""

# Add verbose output
set -x
check_disk_space "$DEB_TARGET"
check_result=$?
set +x

echo "✓ check_disk_space completed with result: $check_result"

echo "All functions completed successfully!"
echo "The hang must be somewhere else..."