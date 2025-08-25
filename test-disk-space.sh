#!/usr/bin/env bash
set -euo pipefail

echo "=== Disk Space Function Test ==="

# Setup same as other scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
if [[ ! -f "$PROJECT_ROOT/config/mirror-sync.conf" && -f "$(pwd)/config/mirror-sync.conf" ]]; then
    PROJECT_ROOT="$(pwd)"
fi

source "$PROJECT_ROOT/lib/common.sh"
load_config

# Test the exact path that's causing issues
DEB_TARGET="/srv/mirrors/debian"
echo "Testing check_disk_space with: $DEB_TARGET"

echo "Before calling check_disk_space..."

# Call with timeout to prevent hanging
if timeout 10 check_disk_space "$DEB_TARGET"; then
    echo "✓ check_disk_space succeeded"
else
    exit_code=$?
    echo "✗ check_disk_space failed or timed out (exit code: $exit_code)"
fi

echo "=== Test complete ==="