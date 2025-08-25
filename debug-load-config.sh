#!/usr/bin/env bash
# Detailed load_config function debugging

echo "=== load_config Function Debugging ==="
echo "Date: $(date)"
echo "PWD: $(pwd)"
echo

# Set up PROJECT_ROOT like the real scripts do
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
if [[ -f "$PROJECT_ROOT/config/mirror-sync.conf" ]]; then
    echo "✓ PROJECT_ROOT correctly detected as: $PROJECT_ROOT"
else
    echo "✗ PROJECT_ROOT detection failed: $PROJECT_ROOT"
    exit 1
fi

# Test 1: Source lib/common.sh to get the load_config function
echo
echo "=== Loading common.sh ==="
if source lib/common.sh 2>&1; then
    echo "✓ lib/common.sh loaded successfully"
else
    echo "✗ Failed to load lib/common.sh"
    exit 1
fi

# Test 2: Debug the load_config function step by step
echo
echo "=== Step-by-step load_config debugging ==="

# Replicate the load_config function with debugging
debug_load_config() {
    local config_file="${1:-}"
    local default_config="${PROJECT_ROOT:-/opt/mirror-sync}/config/mirror-sync.conf"
    
    echo "Function called with config_file: '${config_file}'"
    echo "PROJECT_ROOT: ${PROJECT_ROOT:-UNSET}"
    echo "default_config: $default_config"
    
    # Load default config if it exists
    if [[ -f "$default_config" ]]; then
        echo "✓ Default config file exists, attempting to source..."
        if source "$default_config" 2>&1; then
            echo "✓ Default config sourced successfully"
        else
            echo "✗ Failed to source default config"
            echo "Error details:"
            source "$default_config"
            return 1
        fi
    else
        echo "✗ Default config file not found: $default_config"
        return 1
    fi
    
    # Load custom config if provided
    if [[ -n "$config_file" && -f "$config_file" ]]; then
        echo "Loading custom config: $config_file"
        if source "$config_file" 2>&1; then
            echo "✓ Custom config sourced successfully"
        else
            echo "✗ Failed to source custom config"
            return 1
        fi
    else
        echo "- No custom config provided or file doesn't exist"
    fi
    
    # Load local overrides if they exist
    local local_config="${PROJECT_ROOT:-/opt/mirror-sync}/config/local.conf"
    if [[ -f "$local_config" ]]; then
        echo "Loading local config: $local_config"
        if source "$local_config" 2>&1; then
            echo "✓ Local config sourced successfully"
        else
            echo "✗ Failed to source local config"
            return 1
        fi
    else
        echo "- No local config file (this is normal)"
    fi
    
    echo "✓ debug_load_config completed successfully"
}

# Test the debug version
if debug_load_config; then
    echo "✓ debug_load_config function works"
    echo "Sample variables after loading:"
    echo "  PROJECT_ROOT: ${PROJECT_ROOT:-NOT_SET}"
    echo "  BASE_LOG_DIR: ${BASE_LOG_DIR:-NOT_SET}"
    echo "  DEBIAN_TARGET: ${DEBIAN_TARGET:-NOT_SET}"
else
    echo "✗ debug_load_config function failed"
fi

# Test 3: Try the actual load_config function
echo
echo "=== Testing actual load_config function ==="
if load_config 2>&1; then
    echo "✓ actual load_config function works"
else
    echo "✗ actual load_config function failed"
    echo "Detailed error:"
    set -x
    load_config
    set +x
fi

echo
echo "=== Debug Complete ==="