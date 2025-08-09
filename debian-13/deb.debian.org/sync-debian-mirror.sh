#!/bin/bash
set -e

echo "[*] Starting Debian 12 (bookworm) mirror sync..."

debmirror /debian-mirror \
  --host=deb.debian.org \
  --root=debian \
  --method=http \
  --dist=trixie,trixie-updates,trixie-backports \
  --section=main,contrib,non-free,non-free-firmware \
  --arch=amd64 \
  --di-dist=trixie \
  --di-arch=amd64 \
  --i18n \
  --progress \
  --ignore-missing-release \
  --keyring /usr/share/keyrings/debian-archive-keyring.gpg

echo "[✓] Debian 12 mirror sync complete and ready for offline use."