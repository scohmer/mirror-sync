#!/bin/bash
set -e

echo "[*] Starting Debian 12 (bookworm) mirror sync..."

debmirror /debian-mirror \
  --host=deb.debian.org \
  --root=debian \
  --method=http \
  --dist=bookworm,bookworm-updates \
  --section=main,contrib,non-free,non-free-firmware \
  --arch=amd64 \
  --i18n \
  --progress \
  --no-source \
  --ignore-missing-release

echo "[✓] Debian 12 mirror sync complete."

