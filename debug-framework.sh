#!/usr/bin/env bash
# Debug script to test the framework on remote systems

echo "=== Mirror Sync Framework Debug ==="
echo "Date: $(date)"
echo "User: $(whoami)"
echo "PWD: $(pwd)"
echo

# Test 1: Check if files exist
echo "=== File Existence Check ==="
files_to_check=(
    "lib/common.sh"
    "config/mirror-sync.conf"
    "apt-mirror/debian-build-and-sync.sh"
)

for file in "${files_to_check[@]}"; do
    if [[ -f "$file" ]]; then
        echo "✓ $file exists"
    else
        echo "✗ $file missing"
    fi
done
echo

# Test 2: Try to source the library
echo "=== Library Loading Test ==="
if [[ -f "lib/common.sh" ]]; then
    if source lib/common.sh 2>/dev/null; then
        echo "✓ lib/common.sh loaded successfully"
        
        # Test 3: Try to load config
        echo "=== Configuration Loading Test ==="
        if load_config 2>/dev/null; then
            echo "✓ Configuration loaded successfully"
            echo "PROJECT_ROOT: ${PROJECT_ROOT:-NOT_SET}"
            echo "BASE_LOG_DIR: ${BASE_LOG_DIR:-NOT_SET}"
            echo "DEBIAN_TARGET: ${DEBIAN_TARGET:-NOT_SET}"
        else
            echo "✗ Configuration loading failed"
        fi
        
        # Test 4: Test logging
        echo "=== Logging Test ==="
        if log_info "Test log message" 2>/dev/null; then
            echo "✓ Logging functions work"
        else
            echo "✗ Logging functions failed"
        fi
        
    else
        echo "✗ Failed to load lib/common.sh"
        echo "Error details:"
        source lib/common.sh
    fi
else
    echo "✗ lib/common.sh not found"
fi

# Test 5: Check container runtime
echo
echo "=== Container Runtime Check ==="
if command -v podman >/dev/null 2>&1; then
    echo "✓ podman available: $(podman --version)"
elif command -v docker >/dev/null 2>&1; then
    echo "✓ docker available: $(docker --version)"
else
    echo "✗ No container runtime (podman/docker) found"
fi

# Test 6: Check permissions for target directories
echo
echo "=== Directory Permissions Check ==="
test_dirs=(
    "/srv/mirrors"
    "/var/lock"
    "/opt/mirror-sync"
)

for dir in "${test_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
        if [[ -w "$dir" ]]; then
            echo "✓ $dir exists and is writable"
        else
            echo "⚠ $dir exists but not writable (may need sudo)"
        fi
    else
        echo "- $dir does not exist (will be created by setup)"
    fi
done

echo
echo "=== Debug Complete ==="
echo "Copy this output when reporting issues."