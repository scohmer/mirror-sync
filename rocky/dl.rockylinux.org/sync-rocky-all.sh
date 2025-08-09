#!/usr/bin/env bash
set -euo pipefail

# ================== Config (override via env if needed) ==================
MIRROR_DIR="${MIRROR_DIR:-/srv/yum/rocky/pub}"   # bind-mount this on run
VERSIONS=(${VERSIONS:-8 9 10})
ARCHES=(${ARCHES:-x86_64})

# DNF repo IDs baked into /etc/yum.repos.d/rocky-all.repo (enabled=0)
REPOS_COMMON=(BaseOS AppStream Devel devel extras plus)
REPO_8_ONLY=PowerTools
REPO_9P_ONLY=CRB
# ========================================================================

log(){ printf "[%s] %s\n" "$(date +'%F %T')" "$*"; }

need(){ command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }; }

# Check if a repo exists for the given major/arch (avoids noisy errors)
probe_repo(){
  local ver="$1" repo="$2" arch="$3"
  curl -fsL -o /dev/null \
    "https://dl.rockylinux.org/pub/rocky/${ver}/${repo}/${arch}/os/repodata/repomd.xml"
}

# Sync exactly one repo id (no --disablerepo here; we enable just that ID)
reposync_one(){
  local ver="$1" arch="$2" repoid="$3"
  log "Syncing Rocky ${ver} ${repoid} (${arch}) ..."
  dnf reposync \
    --releasever="${ver}" \
    --repoid="${repoid}" \
    --enablerepo="${repoid}" \
    --arch="${arch}" \
    --download-path="${MIRROR_DIR}/${ver}" \
    --download-metadata \
    --delete \
    --newest-only \
    || log "Failed to sync ${repoid} for Rocky ${ver} (${arch})."
}

# Mirror non-DNF trees for PXE/ISOs over HTTPS (works everywhere)
mirror_tree_https(){
  local url="$1" dest="$2"
  mkdir -p "$dest"
  # Use wget mirroring flags; ignore if 404/not present
  wget -q -e robots=off --mirror --no-parent --no-host-directories \
       --directory-prefix="$dest" "$url" || true
}

sync_images_isos(){
  local ver="$1" arch="$2" base="https://dl.rockylinux.org/pub/rocky/${ver}"
  log "Mirroring images/ for ${ver}/${arch} ..."
  mirror_tree_https "${base}/images/${arch}/" "${MIRROR_DIR}/${ver}/images/${arch}/"
  log "Mirroring isos/ for ${ver}/${arch} ..."
  mirror_tree_https "${base}/isos/${arch}/"   "${MIRROR_DIR}/${ver}/isos/${arch}/"
}

main(){
  need dnf
  need reposync   # from dnf-plugins-core
  need curl
  need wget

  log "Destination: ${MIRROR_DIR}"
  log "Majors: ${VERSIONS[*]} | Arches: ${ARCHES[*]}"

  for ver in "${VERSIONS[@]}"; do
    for arch in "${ARCHES[@]}"; do
      log "=== Rocky Linux ${ver} (${arch}) ==="

      # pick repo set for this major
      repos=("${REPOS_COMMON[@]}")
      if [[ "$ver" -eq 8 ]]; then
        repos+=("$REPO_8_ONLY")
      else
        repos+=("$REPO_9P_ONLY")
      fi

      # sync each repo that actually exists upstream
      for repoid in "${repos[@]}"; do
        if probe_repo "$ver" "$repoid" "$arch"; then
          reposync_one "$ver" "$arch" "$repoid"
        else
          log "Skipping ${ver}/${repoid} (${arch}) – repodata not found."
        fi
      done

      # optional: comment out if you don't need PXE/ISOs mirrored
      sync_images_isos "$ver" "$arch"
    done
  done

  log "Rocky mirror sync complete at ${MIRROR_DIR}"
}

main "$@"
