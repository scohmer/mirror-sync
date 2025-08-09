#!/bin/bash
set -e

MIRROR_DIR="/debian-mirror"
HOST="security.debian.org"
ROOT="debian-security"
ARCH="amd64,i386"
KEYRING="/usr/share/keyrings/debian-archive-keyring.gpg"

DISTS=("bullseye" "bookworm" "trixie")

for dist in "${DISTS[@]}"; do
  suite=$dist-security
  release_url="http://security.debian.org/debian-security/dists/$suite/Release"
  components=$(curl -fsSL "$release_url" | awk '/^Components:/ {for(i=2;i<=NF;i++) printf "%s%s", $i, (i==NF?"":" ")}' | tr ' ' ',')

  echo "[*] [$dist] Starting Debian security sync..."

  debmirror "${MIRROR_DIR}" \
    --host="${HOST}" \
    --root="${ROOT}" \
    --method=http \
    --dist="${suite}" \
    --section="${components}" \
    --arch="${ARCH}" \
    --i18n \
    --progress \
    --ignore-missing-release \
    --keyring "${KEYRING}"

  echo "[✓] [$dist] Debian security sync complete and ready for offline use."
done