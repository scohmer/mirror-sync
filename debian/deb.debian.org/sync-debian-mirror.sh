#!/bin/bash
set -e

MIRROR_DIR="/debian-mirror"
HOST="deb.debian.org"
ROOT="debian"
ARCH="amd64,i386"
KEYRING="/usr/share/keyrings/debian-archive-keyring.gpg"

DISTS=("bullseye" "bullseye-updates" "bullseye-backports" "bookworm" "bookworm-updates" "bookworm-backports" "trixie" "trixie-updates" "trixie-backports")

for dist in "${DISTS[@]}"; do
  echo "[*] [$dist] Fetching Components from Release..."
  release_url="http://${HOST}/${ROOT}/dists/${dist}/Release"
  components=$(curl -fsSL "$release_url" \
    | awk '/^Components:/ {for (i=2;i<=NF;i++) printf "%s%s", $i, (i==NF?"":" ")}' \
    | tr ' ' ',')

  echo "[*] [$dist] Components: ${components}"
  echo "[*] [$dist] Running debmirror..."

  debmirror "${MIRROR_DIR}" \
    --host="${HOST}" \
    --root="${ROOT}" \
    --method=http \
    --dist="${dist}" \
    --section="${components}" \
    --arch="${ARCH}" \
    --i18n \
    --progress \
    --ignore-missing-release \
    --keyring "${KEYRING}"
done

DISTS=("bullseye" "bookworm" "trixie")

for dist in "${DISTS[@]}"; do
  echo "[*] [$dist] Pulling Debian netboot installer..."

  debmirror "${MIRROR_DIR}" \
    --host="${HOST}" \
    --root="${ROOT}" \
    --method=http \
    --dist="${dist}" \
    --section=main \
    --arch="${ARCH}" \
    --di-dist="${dist}" \
    --di-arch="${ARCH}" \
    --i18n \
    --progress \
    --ignore-missing-release \
    --keyring "${KEYRING}"
done

echo "[✓] Debian mirror sync complete."