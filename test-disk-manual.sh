#!/usr/bin/env bash
set -euo pipefail

echo "=== Manual Disk Space Test ==="

# Test the exact logic from check_disk_space function
path="/srv/mirrors/debian"
threshold="85"

echo "Testing path: $path"
echo "Threshold: $threshold"

# Test the directory walking logic
check_path="$path"
counter=0
echo "Starting directory walk..."

while [[ ! -d "$check_path" && "$check_path" != "/" ]]; do
    echo "  $counter: $check_path does not exist"
    check_path="$(dirname "$check_path")"
    echo "  $counter: trying parent: $check_path"
    
    # Safety counter to prevent infinite loop
    ((counter++))
    if [[ $counter -gt 10 ]]; then
        echo "ERROR: Too many iterations, breaking loop"
        break
    fi
done

echo "Final check_path: $check_path"
echo "Directory exists: $(test -d "$check_path" && echo "YES" || echo "NO")"

# Test df command on the final path
echo "Testing df command on: $check_path"
if df_output=$(df "$check_path" 2>&1); then
    echo "✓ df command succeeded:"
    echo "$df_output"
    
    # Test the awk parsing
    echo "Testing awk parsing..."
    usage=$(echo "$df_output" | awk 'NR==2 {print $5}' | sed 's/%//')
    echo "Parsed usage: '$usage'"
    
    if [[ -n "$usage" && "$usage" =~ ^[0-9]+$ ]]; then
        echo "✓ Usage is a valid number: $usage"
        
        if [[ "$usage" -gt "$threshold" ]]; then
            echo "⚠ Usage ($usage%) exceeds threshold ($threshold%)"
        else
            echo "✓ Usage ($usage%) is within threshold ($threshold%)"
        fi
    else
        echo "✗ Invalid usage value: '$usage'"
    fi
else
    echo "✗ df command failed:"
    echo "$df_output"
fi

echo "=== Test complete ==="