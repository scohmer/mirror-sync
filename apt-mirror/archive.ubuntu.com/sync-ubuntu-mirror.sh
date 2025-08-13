#!/bin/bash
set -Eeuo pipefail

# ========= Config (override via env) =========
ARCHS="${ARCHS:-amd64,i386}"                 # e.g. "amd64" or "amd64,i386"
THREADS="${THREADS:-20}"
UBUNTU_VERSIONS="${UBUNTU_VERSIONS:-20.04 22.04 24.04 25.04}"  # space-separated list
INCLUDE_UPDATES="${INCLUDE_UPDATES:-true}"
INCLUDE_BACKPORTS="${INCLUDE_BACKPORTS:-true}"
INCLUDE_SOURCES="${INCLUDE_SOURCES:-true}"   # defaults to true
METADATA_ONLY="${METADATA_ONLY:-false}"      # keep packages by default
MIRROR_ROOT="${MIRROR_ROOT:-/srv/apt/ubuntu-mirror}"

# Mirrors
UBUNTU_MIRROR="${UBUNTU_MIRROR:-http://archive.ubuntu.com/ubuntu}"
UBUNTU_SECURITY_MIRROR="${UBUNTU_SECURITY_MIRROR:-http://security.ubuntu.com/ubuntu}"

# Internal apt-mirror state inside container
BASE_PATH="/var/spool/apt-mirror"
VAR_PATH="$MIRROR_ROOT/var"
SKEL_PATH="$MIRROR_ROOT"

umask 022
mkdir -p "$MIRROR_ROOT" "$VAR_PATH" "$SKEL_PATH"

# ========= Mapping + components =========
codename_for_version() {
  case "$1" in
    20.04) echo "focal"  ;;
    22.04) echo "jammy"  ;;
    24.04) echo "noble"  ;;
    25.04) echo "plucky" ;;  # Ubuntu 25.04 “Plucky Puffin”
    *)     echo "unknown" ;;
  esac
}

# All supported components for Ubuntu
ubuntu_components() {
  echo "main restricted universe multiverse"
}

# ========= Generate /etc/apt/mirror.list =========
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

  # Main + updates/backports per Ubuntu release
  for v in $UBUNTU_VERSIONS; do
    suite="$(codename_for_version "$v")"
    if [[ "$suite" == "unknown" ]]; then
      echo "## Skipping unknown version: $v" >&2
      continue
    fi
    comps="$(ubuntu_components)"

    # main
    echo "deb [arch=$ARCHS] $UBUNTU_MIRROR $suite $comps"
    if [[ "$INCLUDE_SOURCES" == "true" ]]; then
      echo "deb-src $UBUNTU_MIRROR $suite $comps"
    fi

    # -updates
    if [[ "$INCLUDE_UPDATES" == "true" ]]; then
      echo "deb [arch=$ARCHS] $UBUNTU_MIRROR ${suite}-updates $comps"
      if [[ "$INCLUDE_SOURCES" == "true" ]]; then
        echo "deb-src $UBUNTU_MIRROR ${suite}-updates $comps"
      fi
    fi

    # -backports
    if [[ "$INCLUDE_BACKPORTS" == "true" ]]; then
      echo "deb [arch=$ARCHS] $UBUNTU_MIRROR ${suite}-backports $comps"
      if [[ "$INCLUDE_SOURCES" == "true" ]]; then
        echo "deb-src $UBUNTU_MIRROR ${suite}-backports $comps"
      fi
    fi
  done

  echo

  # Security pocket per release
  for v in $UBUNTU_VERSIONS; do
    suite="$(codename_for_version "$v")"
    [[ "$suite" == "unknown" ]] && continue
    comps="$(ubuntu_components)"
    echo "deb [arch=$ARCHS] $UBUNTU_SECURITY_MIRROR ${suite}-security $comps"
    if [[ "$INCLUDE_SOURCES" == "true" ]]; then
      echo "deb-src $UBUNTU_SECURITY_MIRROR ${suite}-security $comps"
    fi
  done

  echo
  echo "clean $UBUNTU_MIRROR"
  echo "clean $UBUNTU_SECURITY_MIRROR"
} > /etc/apt/mirror.list

echo "=== apt-mirror(ubuntu): versions=[$UBUNTU_VERSIONS], archs=[$ARCHS], threads=$THREADS, sources=$INCLUDE_SOURCES ==="
echo "=== mirror_root: $MIRROR_ROOT ==="
apt-mirror
echo "=== apt-mirror finished ==="

# ========= Optional prune for metadata-only mode =========
if [[ "$METADATA_ONLY" == "true" ]]; then
  echo "=== METADATA_ONLY=true: removing package pools ==="
  find "$MIRROR_ROOT" -type d -name pool -prune -exec rm -rf {} +
  find "$MIRROR_ROOT" -type d -empty -delete || true
fi

echo "=== Done. Ubuntu mirror available at: $MIRROR_ROOT ==="

# ========= Notes =========
# - Ubuntu 20.04 (focal) is past standard support; -updates/-security may be limited
#   unless you are entitled to ESM via Ubuntu Pro. This config still lists focal pockets,
#   but expect fewer changes.
