#!/bin/bash
set -euo pipefail

# Destination root for the mirror
MIRROR_DIR="/srv/yum/rocky/pub"

# Architectures to sync
ARCHES=("x86_64")

# Repos to sync with dnf reposync
DNF_REPOS=("AppStream" "BaseOS" "Devel" "PowerTools" "extras" "plus")

# Directories to sync with rsync
RSYNC_DIRS=("images" "isos")

# Rocky versions to mirror
VERSIONS=("8" "9" "10")

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

sync_dnf_repo() {
  local ver="$1"
  local repo="$2"
  local arch="$3"

  log "Syncing Rocky ${ver} ${repo} (${arch}) ..."
  dnf reposync \
    --repoid="${repo}" \
    --releasever="${ver}" \
    --arch="${arch}" \
    --download-path="${MIRROR_DIR}/${ver}" \
    --download-metadata \
    --delete \
    --newest-only || log "Failed to sync ${repo} for Rocky ${ver}."
}

sync_rsync_dir() {
  local ver="$1"
  local dir="$2"
  local arch="$3"

  local src="rsync://dl.rockylinux.org/rocky/${ver}/${dir}/${arch}/"
  local dest="${MIRROR_DIR}/${ver}/${dir}/${arch}/"

  log "Syncing Rocky ${ver} ${dir} (${arch}) ..."
  rsync -av --delete --partial "$src" "$dest" || log "${dir} not found for Rocky ${ver}."
}

main() {
  for ver in "${VERSIONS[@]}"; do
    for arch in "${ARCHES[@]}"; do
      for repo in "${DNF_REPOS[@]}"; do
        sync_dnf_repo "$ver" "$repo" "$arch"
      done
      for dir in "${RSYNC_DIRS[@]}"; do
        sync_rsync_dir "$ver" "$dir" "$arch"
      done
    done
  done
}

main "$@"
