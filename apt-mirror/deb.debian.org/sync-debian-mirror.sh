#!/bin/bash
set -Eeuo pipefail

ARCHS="${ARCHS:-amd64}"
THREADS="${THREADS:-20}"
SUITES="${SUITES:-bullseye bookworm trixie}"
INCLUDE_UPDATES="${INCLUDE_UPDATES:-true}"
INCLUDE_BACKPORTS="${INCLUDE_BACKPORTS:-true}"   # you can set false if not needed
METADATA_ONLY="${METADATA_ONLY:-false}"          # <-- default to full mirror
MIRROR_ROOT="${MIRROR_ROOT:-/srv/apt/apt-mirror}"

BASE_PATH="/var/spool/apt-mirror"
VAR_PATH="$BASE_PATH/var"
SKEL_PATH="$BASE_PATH/skel"

umask 022
mkdir -p "$MIRROR_ROOT" "$BASE_PATH" "$VAR_PATH" "$SKEL_PATH"

{
  echo "set base_path    $BASE_PATH"
  echo "set mirror_path  $MIRROR_ROOT"
  echo "set skel_path    $SKEL_PATH"
  echo "set var_path     $VAR_PATH"
  echo "set cleanscript  \$var_path/clean.sh"
  echo "set defaultarch  ${ARCHS%%,*}"
  echo "set nthreads     $THREADS"
  echo "set _tilde       0"
  echo

  for s in $SUITES; do
    echo "deb [arch=$ARCHS] http://deb.debian.org/debian $s main contrib non-free non-free-firmware"
    if [[ "$INCLUDE_UPDATES" == "true" ]]; then
      echo "deb [arch=$ARCHS] http://deb.debian.org/debian ${s}-updates main contrib non-free non-free-firmware"
    fi
    if [[ "$INCLUDE_BACKPORTS" == "true" ]]; then
      echo "deb [arch=$ARCHS] http://deb.debian.org/debian ${s}-backports main contrib non-free non-free-firmware"
    fi
  done

  echo
  for s in $SUITES; do
    echo "deb [arch=$ARCHS] http://security.debian.org/debian-security ${s}-security main contrib non-free non-free-firmware"
  done

  echo
  echo "clean http://deb.debian.org/debian"
  echo "clean http://security.debian.org/debian-security"
} > /etc/apt/mirror.list

echo "=== Running apt-mirror for: $SUITES (archs: $ARCHS) ==="
apt-mirror
echo "=== apt-mirror finished ==="

# Keep packages for disconnected mirror — only prune if explicitly requested
if [[ "$METADATA_ONLY" == "true" ]]; then
  echo "=== Pruning pool/ (metadata-only requested) ==="
  find "$MIRROR_ROOT" -type d -name pool -prune -exec rm -rf {} +
fi

echo "=== Done. Mirror at: $MIRROR_ROOT ==="
