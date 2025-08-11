#!/bin/bash
set -euo pipefail

MIRROR_DIR="${MIRROR_DIR:-/debian-mirror}"
HOST="${HOST:-deb.debian.org}"
KEYRING="${KEYRING:-/usr/share/keyrings/debian-archive-keyring.gpg}"
ARCH="${ARCH:-amd64,i386}"
SECTIONS_DEFAULT="${SECTIONS_DEFAULT:-main,contrib,non-free,non-free-firmware}"

# Split main vs security (security uses a different root)
DISTS_MAIN=(bullseye bullseye-updates bullseye-backports bookworm bookworm-updates bookworm-backports trixie trixie-updates)
DISTS_SEC=(bullseye-security bookworm-security trixie-security)

fetch_components() {
  local dist="$1"
  local root="$2"
  local url="https://${HOST}/${root}/dists/${dist}/Release"
  local comps
  comps="$(curl -fsSL "$url" | awk '/^Components:/ {for (i=2;i<=NF;i++) printf "%s%s",$i,(i==NF?"":" ")}' || true)"
  if [[ -z "$comps" ]]; then
    echo "$SECTIONS_DEFAULT"
  else
    echo "$comps" | tr ' ' ','
  fi
}

run_debmirror() {
  local dist="$1" root="$2" comps="$3"
  echo "[*] [$dist] Components: ${comps}"
  debmirror "${MIRROR_DIR}" \
    --method=http \
    --host="${HOST}" \
    --root="${root}" \
    --dist="${dist}" \
    --section="${comps}" \
    --arch="${ARCH}" \
    --i18n \
    --progress \
    --cleanup \
    --timeout 120 \
    --keyring "${KEYRING}"
}

# MAIN archive
for dist in "${DISTS_MAIN[@]}"; do
  echo "[*] [$dist] Resolving components from Release..."
  comps="$(fetch_components "$dist" "debian")"
  echo "[*] [$dist] Running debmirror (main)..."
  run_debmirror "$dist" "debian" "$comps"
done

MIRROR_DIR="${MIRROR_DIR:-/security-mirror}"
# SECURITY archive (different root)
for dist in "${DISTS_SEC[@]}"; do
  echo "[*] [$dist] Resolving components from Release..."
  comps="$(fetch_components "$dist" "debian-security")"
  echo "[*] [$dist] Running debmirror (security)..."
  run_debmirror "$dist" "debian-security" "$comps"
done

echo "[✓] Debian mirror sync complete."
