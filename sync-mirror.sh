#!/bin/bash
set -e

echo "[*] Starting debmirror sync..."
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
echo "[✓] Mirror sync complete."
