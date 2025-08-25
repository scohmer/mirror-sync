#!/usr/bin/env bash
set -euo pipefail

echo "=== Minimal Framework Test ==="
echo "PWD: $(pwd)"

# Replicate the exact same setup as debian-build-and-sync.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Fix for when running from project root
if [[ ! -f "$PROJECT_ROOT/config/mirror-sync.conf" && -f "$(pwd)/config/mirror-sync.conf" ]]; then
    PROJECT_ROOT="$(pwd)"
fi

echo "PROJECT_ROOT: $PROJECT_ROOT"

# Try to source the library
echo "Sourcing lib/common.sh..."
source "$PROJECT_ROOT/lib/common.sh"
echo "✓ Library sourced successfully"

# Try to load config
echo "Loading configuration..."
load_config
echo "✓ Configuration loaded successfully"

# Try the logging function that's failing
LOG_DIR="${BASE_LOG_DIR:-/opt/mirror-sync/logs}/debian"
echo "LOG_DIR: $LOG_DIR"

echo "Calling setup_logging..."
setup_logging "$LOG_DIR" "debian"
echo "✓ setup_logging completed successfully"

echo "=== Test completed successfully ==="