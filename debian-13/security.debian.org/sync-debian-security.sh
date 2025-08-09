#!/bin/bash
set -e

echo "[*] Starting Debian 13 (trixie) security sync..."

debmirror /debian-mirror \
  --host=security.debian.org \
  --root=debian-security \
  --method=http \
  --dist=trixie-security \
  --section=main,contrib,non-free,non-free-firmware,updates \
  --arch=amd64,i386 \
  --i18n \
  --progress \
  --ignore-missing-release \
  --keyring /usr/share/keyrings/debian-archive-keyring.gpg

echo "[✓] Debian 13 security sync complete and ready for offline use."