#!/bin/bash
set -e

echo "[*] Starting Debian 11 (bullseye) security sync..."

debmirror /debian-mirror \
  --host=security.debian.org \
  --root=debian-security \
  --method=http \
  --dist=bullseye-security \
  --section=main,contrib,non-free,non-free-firmware,updates \
  --arch=amd64,i386 \
  --i18n \
  --progress \
  --ignore-missing-release \
  --keyring /usr/share/keyrings/debian-archive-keyring.gpg

echo "[✓] Debian 11 security sync complete and ready for offline use."