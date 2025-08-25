#!/usr/bin/env bash
set -euo pipefail

echo "=== Lock Function Test ==="
echo "PWD: $(pwd)"

# Replicate the exact same setup as debian-build-and-sync.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Fix for when running from project root
if [[ ! -f "$PROJECT_ROOT/config/mirror-sync.conf" && -f "$(pwd)/config/mirror-sync.conf" ]]; then
    PROJECT_ROOT="$(pwd)"
fi

echo "PROJECT_ROOT: $PROJECT_ROOT"

# Source the library and load config
source "$PROJECT_ROOT/lib/common.sh"
load_config

# Set up the same variables as debian script
LOCK_FILE="/var/lock/debian-mirror-sync.lock"
echo "LOCK_FILE: $LOCK_FILE"

# Test the exact functions that are called in sequence
echo "Testing wait_for_network..."
wait_for_network
echo "✓ wait_for_network completed"

echo "Testing check_disk_space..."
if check_disk_space "/srv/mirrors/debian"; then
    echo "✓ check_disk_space completed"
else
    echo "⚠ check_disk_space returned warning (expected if disk usage high)"
fi

echo "Testing lock_or_exit..."
echo "About to call: lock_or_exit \"$LOCK_FILE\" \"debian-mirror-sync\""
lock_or_exit "$LOCK_FILE" "debian-mirror-sync"
echo "✓ lock_or_exit completed"

echo "=== Test completed successfully ==="