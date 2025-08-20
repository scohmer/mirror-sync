#!/bin/bash
set -Eeuo pipefail

# ========= Config (override via env) =========
ARCHS="${ARCHS:-amd64,i386}"                 # e.g. "amd64" or "amd64,i386"
THREADS="${THREADS:-20}"
SUITES="${SUITES:-bullseye bookworm trixie}"
INCLUDE_UPDATES="${INCLUDE_UPDATES:-true}"
INCLUDE_BACKPORTS="${INCLUDE_BACKPORTS:-true}"
INCLUDE_SOURCES="${INCLUDE_SOURCES:-true}" # now defaults to true
METADATA_ONLY="${METADATA_ONLY:-false}"    # disconnected mirror => keep packages by default
MIRROR_ROOT="${MIRROR_ROOT:-/srv/apt/debian}"

# Internal apt-mirror state inside container
BASE_PATH="/var/spool/apt-mirror"
VAR_PATH="$MIRROR_ROOT/var"
SKEL_PATH="$MIRROR_ROOT"

umask 022
mkdir -p "$MIRROR_ROOT" "$VAR_PATH" "$SKEL_PATH"

# ========= Per-suite components =========
# bullseye does NOT have 'non-free-firmware'; bookworm/trixie do.
comps_for_suite() {
  case "$1" in
    bullseye) echo "main contrib non-free" ;;
    *)        echo "main contrib non-free non-free-firmware" ;;
  esac
}

# Backports origin:
# - bullseye-backports moved off the main mirror; use archive.debian.org
# - bookworm/trixie backports stay on deb.debian.org
backports_url_for_suite() {
  case "$1" in
    bullseye) echo "http://archive.debian.org/debian" ;;
    *)        echo "http://deb.debian.org/debian" ;;
  esac
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

  # Main + updates/backports
  for s in $SUITES; do
    comps="$(comps_for_suite "$s")"

    # main
    echo "deb http://deb.debian.org/debian $s $comps"
    echo "deb-i386 http://deb.debian.org/debian $s $comps"
    if [[ "$INCLUDE_SOURCES" == "true" ]]; then
      echo "deb-src http://deb.debian.org/debian $s $comps"
    fi

    # -updates
    if [[ "$INCLUDE_UPDATES" == "true" ]]; then
      echo "deb http://deb.debian.org/debian ${s}-updates $comps"
      echo "deb-i386 http://deb.debian.org/debian ${s}-updates $comps"
      if [[ "$INCLUDE_SOURCES" == "true" ]]; then
        echo "deb-src http://deb.debian.org/debian ${s}-updates $comps"
      fi
    fi

    # -backports
    if [[ "$INCLUDE_BACKPORTS" == "true" ]]; then
      bkp_url="$(backports_url_for_suite "$s")"
      echo "deb $bkp_url ${s}-backports $comps"
      echo "deb-i386 $bkp_url ${s}-backports $comps"
      if [[ "$INCLUDE_SOURCES" == "true" ]]; then
        echo "deb-src $bkp_url ${s}-backports $comps"
      fi
    fi
  done

  echo

  # Security for each suite
  for s in $SUITES; do
    comps="$(comps_for_suite "$s")"
    echo "deb http://security.debian.org/debian-security ${s}-security $comps"
    echo "deb-i386 http://security.debian.org/debian-security ${s}-security $comps"
    if [[ "$INCLUDE_SOURCES" == "true" ]]; then
      echo "deb-src http://security.debian.org/debian-security ${s}-security $comps"
    fi
  done

  echo
  echo "clean http://deb.debian.org/debian"
  echo "clean http://security.debian.org/debian-security"
  if echo "$SUITES" | grep -qw bullseye && [[ "$INCLUDE_BACKPORTS" == "true" ]]; then
    echo "clean http://archive.debian.org/debian"
  fi
} > /etc/apt/mirror.list

echo "=== apt-mirror: suites=[$SUITES], archs=[$ARCHS], threads=$THREADS, sources=$INCLUDE_SOURCES ==="
echo "=== mirror_root: $MIRROR_ROOT ==="
apt-mirror
echo "=== apt-mirror finished ==="

# ========= Optional prune for metadata-only mode =========
if [[ "$METADATA_ONLY" == "true" ]]; then
  echo "=== METADATA_ONLY=true: removing package pools ==="
  find "$MIRROR_ROOT" -type d -name pool -prune -exec rm -rf {} +
  find "$MIRROR_ROOT" -type d -empty -delete || true
fi

echo "=== Done. Mirror available at: $MIRROR_ROOT ==="
