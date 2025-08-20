#!/bin/bash
set -Eeuo pipefail

ARCHS="${ARCHS:-amd64,i386}"
THREADS="${THREADS:-20}"
SUITES="${SUITES:-bullseye bookworm trixie}"
INCLUDE_UPDATES="${INCLUDE_UPDATES:-true}"
INCLUDE_BACKPORTS="${INCLUDE_BACKPORTS:-true}"
INCLUDE_SOURCES="${INCLUDE_SOURCES:-true}"
METADATA_ONLY="${METADATA_ONLY:-false}"
MIRROR_ROOT="${MIRROR_ROOT:-/srv/apt/debian}"

BASE_PATH="/var/spool/apt-mirror"
VAR_PATH="$MIRROR_ROOT/var"
SKEL_PATH="$MIRROR_ROOT"

umask 022
mkdir -p "$MIRROR_ROOT" "$VAR_PATH" "$SKEL_PATH"

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

gen_list() {
  local arch="$1"
  {
    echo "set base_path    $BASE_PATH"
    echo "set mirror_path  $MIRROR_ROOT"
    echo "set skel_path    $SKEL_PATH"
    echo "set var_path     $VAR_PATH"
    echo "set cleanscript  \$var_path/clean.sh"
    echo "set defaultarch  $arch"
    echo "set nthreads     $THREADS"
    echo "set _tilde       0"
    echo

    for s in $SUITES; do
      comps="$(comps_for_suite "$s")"
      echo "deb http://deb.debian.org/debian $s $comps"
      [[ "$INCLUDE_SOURCES" == "true" ]] && echo "deb-src http://deb.debian.org/debian $s $comps"

      if [[ "$INCLUDE_UPDATES" == "true" ]]; then
        echo "deb http://deb.debian.org/debian ${s}-updates $comps"
        [[ "$INCLUDE_SOURCES" == "true" ]] && echo "deb-src http://deb.debian.org/debian ${s}-updates $comps"
      fi

      if [[ "$INCLUDE_BACKPORTS" == "true" ]]; then
        bkp_url="$(backports_url_for_suite "$s")"
        echo "deb $bkp_url ${s}-backports $comps"
        [[ "$INCLUDE_SOURCES" == "true" ]] && echo "deb-src $bkp_url ${s}-backports $comps"
      fi
    done

    echo
    for s in $SUITES; do
      comps="$(comps_for_suite "$s")"
      echo "deb http://security.debian.org/debian-security ${s}-security $comps"
      [[ "$INCLUDE_SOURCES" == "true" ]] && echo "deb-src http://security.debian.org/debian-security ${s}-security $comps"
    done

    echo
    echo "clean http://deb.debian.org/debian"
    echo "clean http://security.debian.org/debian-security"
    if echo "$SUITES" | grep -qw bullseye && [[ "$INCLUDE_BACKPORTS" == "true" ]]; then
      echo "clean http://archive.debian.org/debian"
    fi
  }
}

IFS=',' read -ra ARCH_LIST <<< "$ARCHS"
for A in "${ARCH_LIST[@]}"; do
  LIST="/etc/apt/mirror-${A}.list"
  gen_list "$A" > "$LIST"
  echo "=== apt-mirror ($A): suites=[$SUITES], threads=$THREADS, sources=$INCLUDE_SOURCES ==="
  apt-mirror "$LIST"
done

if [[ "$METADATA_ONLY" == "true" ]]; then
  echo "=== METADATA_ONLY=true: removing package pools ==="
  find "$MIRROR_ROOT" -type d -name pool -prune -exec rm -rf {} +
  find "$MIRROR_ROOT" -type d -empty -delete || true
fi

echo "=== Done. Mirror at: $MIRROR_ROOT ==="
