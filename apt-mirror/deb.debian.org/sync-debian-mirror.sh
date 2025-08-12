#!/bin/bash
set -Eeuo pipefail

# ========= Config (override via env) =========
ARCHS="${ARCHS:-amd64}"
THREADS="${THREADS:-20}"
SUITES="${SUITES:-bullseye bookworm trixie}"
INCLUDE_UPDATES="${INCLUDE_UPDATES:-true}"
INCLUDE_BACKPORTS="${INCLUDE_BACKPORTS:-true}"
METADATA_ONLY="${METADATA_ONLY:-false}"
MIRROR_ROOT="${MIRROR_ROOT:-/srv/apt/apt-mirror}"

# Internal apt-mirror state paths (now under MIRROR_ROOT)
BASE_PATH="/var/spool/apt-mirror"      # still required but can be minimal
VAR_PATH="$MIRROR_ROOT/var"
SKEL_PATH="$MIRROR_ROOT/skel"

umask 022
mkdir -p "$MIRROR_ROOT" "$VAR_PATH" "$SKEL_PATH"

# ========= Per-suite components =========
comps_for_suite() {
  case "$1" in
    bullseye) echo "main contrib non-free" ;;
    *)        echo "main contrib non-free non-free-firmware" ;;
  esac
}

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

  for s in $SUITES; do
    comps="$(comps_for_suite "$s")"
    echo "deb [arch=$ARCHS] http://deb.debian.org/debian $s $comps"
    if [[ "$INCLUDE_UPDATES" == "true" ]]; then
      echo "deb [arch=$ARCHS] http://deb.debian.org/debian ${s}-updates $comps"
    fi
    if [[ "$INCLUDE_BACKPORTS" == "true" ]]; then
      bkp_url="$(backports_url_for_suite "$s")"
      echo "deb [arch=$ARCHS] $bkp_url ${s}-backports $comps"
    fi
  done

  echo
  for s in $SUITES; do
    comps="$(comps_for_suite "$s")"
    echo "deb [arch=$ARCHS] http://security.debian.org/debian-security ${s}-security $comps"
  done

  echo
  echo "clean http://deb.debian.org/debian"
  echo "clean http://security.debian.org/debian-security"
  if echo "$SUITES" | grep -qw bullseye && [[ "$INCLUDE_BACKPORTS" == "true" ]]; then
    echo "clean http://archive.debian.org/debian"
  fi
} > /etc/apt/mirror.list

echo "=== apt-mirror: suites=[$SUITES], archs=[$ARCHS], threads=$THREADS ==="
echo "=== mirror_root: $MIRROR_ROOT ==="
apt-mirror
echo "=== apt-mirror finished ==="

if [[ "$METADATA_ONLY" == "true" ]]; then
  echo "=== METADATA_ONLY=true: removing package pools ==="
  find "$MIRROR_ROOT" -type d -name pool -prune -exec rm -rf {} +
  find "$MIRROR_ROOT" -type d -empty -delete || true
fi

echo "=== Done. Mirror available at: $MIRROR_ROOT ==="
