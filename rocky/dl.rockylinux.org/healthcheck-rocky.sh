#!/bin/bash
# Health check for Rocky Linux mirror container

set -e

# Check if we can reach Rocky Linux upstream
if ! curl -f -s --connect-timeout 10 https://dl.rockylinux.org/pub/rocky/ >/dev/null; then
    echo "UNHEALTHY: Cannot reach Rocky Linux upstream"
    exit 1
fi

# Check if mirror directory exists and has some content
if [[ ! -d "/srv/mirrors/rocky" ]]; then
    echo "UNHEALTHY: Rocky mirror directory does not exist"
    exit 1
fi

# Check if we have at least one version directory
if [[ -z "$(find /srv/mirrors/rocky -mindepth 1 -maxdepth 2 -name "rocky" -type d 2>/dev/null | head -1)" ]]; then
    echo "HEALTHY: Mirror directory exists but no content yet (initial state)"
    exit 0
fi

# Check if recent repodata exists (within last 7 days)
recent_metadata=$(find /srv/mirrors/rocky -name "repomd.xml" -mtime -7 2>/dev/null | wc -l)
if [[ "$recent_metadata" -eq 0 ]]; then
    echo "UNHEALTHY: No recent repository metadata found"
    exit 1
fi

echo "HEALTHY: Rocky mirror checks passed"
exit 0