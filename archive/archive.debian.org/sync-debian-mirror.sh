#!/bin/bash
set -e

echo "[*] Starting Debian 10 (buster) mirror sync..."

debmirror /debian-mirror \
  --host=archive.debian.org \
  --root=debian \
  --method=http \
  --dist=buster,buster-updates,buster-backports \
  --section=main,contrib,non-free \
  --arch=amd64,i386 \
  --di-dist=buster \
  --di-arch=amd64,i386 \
  --i18n \
  --progress \
  --ignore-missing-release \
  --keyring /usr/share/keyrings/debian-archive-keyring.gpg

echo "[✓] Debian 10 mirror sync complete and ready for offline use."