#!/bin/bash
# Basic health check for mirror containers

set -e

# Check if we can reach the internet
if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
    echo "UNHEALTHY: No internet connectivity"
    exit 1
fi

# Check if mirror directory exists and is writable
if [[ ! -d "/srv/mirrors" ]]; then
    echo "UNHEALTHY: Mirror directory does not exist"
    exit 1
fi

if [[ ! -w "/srv/mirrors" ]]; then
    echo "UNHEALTHY: Mirror directory is not writable"
    exit 1
fi

echo "HEALTHY: All checks passed"
exit 0