#!/bin/bash
set -e

echo "[*] Starting Debian 11 (bullseye) mirror sync..."

debmirror /debian-mirror \
  --host=deb.debian.org \
  --root=debian \
  --method=http \
  --dist=bullseye,bullseye-updates,bullseye-backports \
  --section=main,contrib,non-free,non-free-firmware \
  --arch=amd64,i386 \
  --di-dist=bullseye \
  --di-arch=amd64 \
  --i18n \
  --progress \
  --ignore-missing-release \
  --keyring /usr/share/keyrings/debian-archive-keyring.gpg

echo "[✓] Debian 11 mirror sync complete and ready for offline use."