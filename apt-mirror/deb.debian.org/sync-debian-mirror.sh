#!/bin/bash
set -Eeuo pipefail

# Configurables via env (override at run time if you like)
ARCHS="${ARCHS:-amd64}"
THREADS="${THREADS:-20}"
MIRROR_ROOT="${MIRROR_ROOT:-/srv/apt/debian/deb.debian.org/debian}"

# Internal apt-mirror paths (state/spool live inside the container)
BASE_PATH="/var/spool/apt-mirror"
VAR_PATH="$BASE_PATH/var"
SKEL_PATH="$BASE_PATH/skel"

mkdir -p "$MIRROR_ROOT" "$BASE_PATH" "$VAR_PATH" "$SKEL_PATH"

# Suites for Debian 11/12/13
# 11 -> bullseye, 12 -> bookworm, 13 -> trixie
cat > /etc/apt/mirror.list <<EOF
set base_path    $BASE_PATH
set mirror_path  $MIRROR_ROOT
set skel_path    $SKEL_PATH
set var_path     $VAR_PATH
set cleanscript  \$var_path/clean.sh
set defaultarch  ${ARCHS%%,*}     # first arch if multiple provided
set nthreads     $THREADS
set _tilde       0

# Main repositories
deb [arch=$ARCHS] http://deb.debian.org/debian bullseye main contrib non-free non-free-firmware
deb [arch=$ARCHS] http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb [arch=$ARCHS] http://deb.debian.org/debian trixie   main contrib non-free non-free-firmware

# Security repositories
deb [arch=$ARCHS] http://security.debian.org/debian-security bullseye-security main contrib non-free non-free-firmware
deb [arch=$ARCHS] http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb [arch=$ARCHS] http://security.debian.org/debian-security trixie-security   main contrib non-free non-free-firmware

# Clean directives
clean http://deb.debian.org/debian
clean http://security.debian.org/debian-security
EOF

echo "=== Starting apt-mirror sync for Debian 11/12/13 (bullseye/bookworm/trixie) ==="
apt-mirror
echo "=== apt-mirror finished; pruning package pools (metadata-only mirror) ==="

# Remove any pool/ directories to keep only dists/ metadata
# This intentionally removes packages for all suites to keep the mirror lightweight.
find "$MIRROR_ROOT" -type d -name pool -prune -exec rm -rf {} +

echo "=== Done. dists/ metadata for 11/12/13 is synced under: $MIRROR_ROOT ==="
