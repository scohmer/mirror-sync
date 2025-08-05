#!/bin/bash
set -e

DISTS=("bullseye" "bookworm" "trixie")

for dist in "${DISTS[@]}"; do
  echo "[*] Syncing $dist into unified mirror..."
  debmirror /debian-mirror \
    --host=deb.debian.org \
    --root=debian \
    --method=http \
    --dist=$dist,$dist-updates \
    --section=main,contrib,non-free,non-free-firmware \
    --arch=amd64 \
    --i18n \
    --progress \
    --no-source \
    --ignore-missing-release
done
