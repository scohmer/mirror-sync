#!/bin/bash
set -Eeuo pipefail

# ========= Config (override via env) =========
ARCHS="${ARCHS:-amd64}"                 # e.g. "amd64" or "amd64,arm64"
THREADS="${THREADS:-20}"
SUITES="${SUITES:-bullseye bookworm trixie}"
INCLUDE_UPDATES="${INCLUDE_UPDATES:-true}"
INCLUDE_BACKPORTS="${INCLUDE_BACKPORTS:-true}"
METADATA_ONLY="${METADATA_ONLY:-false}" # disconnected mirror => keep packages by default
MIRROR_ROOT="${MIRROR_ROOT:-/srv/apt/apt-mirror}"

# Internal apt-mirror state inside container
BASE_PATH="/var/spool/apt-mirror"
VAR_PATH="$BASE_PATH/var"
SKEL_PATH="$BASE_PATH/skel"

umask 022
mkdir -p "$MIRROR_ROOT" "$BASE_PATH" "$VAR_PATH" "$SKEL_PATH"

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
    echo "deb [arch=$ARCHS] http://deb.debian.org/debian $s $comps"

    # -updates
    if [[ "$INCLUDE_UPDATES" == "true" ]]; then
      echo "deb [arch=$ARCHS] http://deb.debian.org/debian ${s}-updates $comps"
    fi

    # -backports (bullseye from archive, others from deb.debian.org)
    if [[ "$INCLUDE_BACKPORTS" == "true" ]]; then
      bkp_url="$(backports_url_for_suite "$s")"
      echo "deb [arch=$ARCHS] $bkp_url ${s}-backports $comps"
    fi
  done

  echo

  # Security for each suite
  for s in $SUITES; do
    comps="$(comps_for_suite "$s")"
    echo "deb [arch=$ARCHS] http://security.debian.org/debian-security ${s}-security $comps"
  done

  echo
  echo "clean http://deb.debian.org/debian"
  echo "clean http://security.debian.org/debian-security"
  # Optional: clean archive if you used it for bullseye-backports
  if echo "$SUITES" | grep -qw bullseye && [[ "$INCLUDE_BACKPORTS" == "true" ]]; then
    echo "clean http://archive.debian.org/debian"
  fi
} > /etc/apt/mirror.list

echo "=== apt-mirror: suites=[$SUITES], archs=[$ARCHS], threads=$THREADS ==="
echo "=== mirror_root: $MIRROR_ROOT ==="
apt-mirror
echo "=== apt-mirror finished ==="

# ========= Optional prune for metadata-only mode =========
if [[ "$METADATA_ONLY" == "true" ]]; then
  echo "=== METADATA_ONLY=true: removing package pools ==="
  # remove all pool/ dirs directly under the mirror root hierarchy
  find "$MIRROR_ROOT" -type d -name pool -prune -exec rm -rf {} +
  # tidy empty dirs left behind
  find "$MIRROR_ROOT" -type d -empty -delete || true
fi

echo "=== Done. Mirror available at: $MIRROR_ROOT ==="
