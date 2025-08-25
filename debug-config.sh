#!/usr/bin/env bash
# Detailed configuration debugging script

echo "=== Configuration Loading Debug ==="
echo "Date: $(date)"
echo "User: $(whoami)"
echo "PWD: $(pwd)"
echo

# Step 1: Check PROJECT_ROOT detection
echo "=== PROJECT_ROOT Detection ==="
echo "SCRIPT_DIR detection test:"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "SCRIPT_DIR: $SCRIPT_DIR"

# Fix: If we're in the root of mirror-sync, PROJECT_ROOT should be SCRIPT_DIR, not its parent
if [[ -f "$SCRIPT_DIR/config/mirror-sync.conf" ]]; then
    PROJECT_ROOT="$SCRIPT_DIR"
    echo "PROJECT_ROOT (corrected): $PROJECT_ROOT"
else
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
    echo "PROJECT_ROOT (calculated): $PROJECT_ROOT"
fi

if [[ -d "$PROJECT_ROOT/config" ]]; then
    echo "✓ config directory found at: $PROJECT_ROOT/config"
else
    echo "✗ config directory NOT found at: $PROJECT_ROOT/config"
fi
echo

# Step 2: Test config file paths
echo "=== Config File Path Testing ==="
default_config="${PROJECT_ROOT:-/opt/mirror-sync}/config/mirror-sync.conf"
echo "Default config path: $default_config"
if [[ -f "$default_config" ]]; then
    echo "✓ Default config file exists"
    echo "File size: $(wc -l < "$default_config") lines"
else
    echo "✗ Default config file missing"
fi

local_config="${PROJECT_ROOT:-/opt/mirror-sync}/config/local.conf"
echo "Local config path: $local_config"
if [[ -f "$local_config" ]]; then
    echo "✓ Local config file exists"
else
    echo "- Local config file doesn't exist (this is normal)"
fi
echo

# Step 3: Test manual config loading
echo "=== Manual Configuration Loading Test ==="
if [[ -f "$default_config" ]]; then
    echo "Attempting to source default config..."
    if source "$default_config" 2>&1; then
        echo "✓ Default config sourced successfully"
        echo "Sample variables:"
        echo "  PROJECT_ROOT: ${PROJECT_ROOT:-NOT_SET}"
        echo "  BASE_LOG_DIR: ${BASE_LOG_DIR:-NOT_SET}"
        echo "  DEBIAN_TARGET: ${DEBIAN_TARGET:-NOT_SET}"
        echo "  CONTAINER_RUNTIME: ${CONTAINER_RUNTIME:-NOT_SET}"
    else
        echo "✗ Failed to source default config"
        echo "Error details:"
        source "$default_config"
    fi
else
    echo "✗ Cannot test - config file missing"
fi
echo

# Step 4: Test the load_config function manually
echo "=== load_config Function Test ==="
if [[ -f "lib/common.sh" ]]; then
    # Define load_config function manually for testing
    load_config_test() {
        local config_file="${1:-}"
        local default_config="${PROJECT_ROOT:-/opt/mirror-sync}/config/mirror-sync.conf"
        
        echo "  Testing with PROJECT_ROOT: ${PROJECT_ROOT:-UNSET}"
        echo "  Looking for config at: $default_config"
        
        # Load default config if it exists
        if [[ -f "$default_config" ]]; then
            echo "  Sourcing: $default_config"
            source "$default_config"
        else
            echo "  Config file not found: $default_config"
            return 1
        fi
        
        # Load custom config if provided
        [[ -n "$config_file" && -f "$config_file" ]] && source "$config_file"
        
        # Load local overrides if they exist
        local local_config="${PROJECT_ROOT:-/opt/mirror-sync}/config/local.conf"
        [[ -f "$local_config" ]] && source "$local_config"
    }
    
    if load_config_test 2>&1; then
        echo "✓ load_config function works"
    else
        echo "✗ load_config function failed"
    fi
else
    echo "✗ lib/common.sh not found"
fi

echo
echo "=== Recommendations ==="
if [[ ! -f "$default_config" ]]; then
    echo "1. Run the setup script: sudo ./scripts/setup-mirrors.sh all"
    echo "2. Or manually create config directory: mkdir -p config"
fi

if [[ "$PWD" != */mirror-sync ]]; then
    echo "3. Make sure you're in the mirror-sync directory"
    echo "   Current: $PWD"
    echo "   Expected: .../mirror-sync"
fi

echo
echo "=== End Configuration Debug ==="