#!/usr/bin/env bash
set -euo pipefail

# Where to write on the host (bind-mount this path)
MIRROR_DIR="${MIRROR_DIR:-/srv/yum/rocky/pub}"

# What to sync (majors, arches, repo IDs)
VERSIONS=(${VERSIONS:-8 9 10})
ARCHES=(${ARCHES:-x86_64})
REPOS_COMMON=(BaseOS AppStream Devel devel extras plus)
REPO_8_ONLY=PowerTools
REPO_9P_ONLY=CRB

log(){ printf "[%s] %s\n" "$(date +'%F %T')" "$*"; }

probe_repo() {
  local ver="$1" repo="$2" arch="$3"
  curl -fsL -o /dev/null "https://dl.rockylinux.org/pub/rocky/${ver}/${repo}/${arch}/os/repodata/repomd.xml"
}

reposync_one() {
  local ver="$1" arch="$2" repoid="$3"
  log "Syncing Rocky ${ver} ${repoid} (${arch}) ..."
  dnf reposync \
    --releasever="${ver}" \
    --disablerepo='*' \
    --enablerepo="${repoid}" \
    --repoid="${repoid}" \
    --arch="${arch}" \
    --download-path="${MIRROR_DIR}/${ver}" \
    --download-metadata \
    --delete \
    --newest-only \
    || log "Failed to sync ${repoid} for Rocky ${ver} (${arch})."
}

# OPTIONAL: images + isos over HTTPS (no rsync requirement)
sync_images_isos() {
  local ver="$1" arch="$2" base="https://dl.rockylinux.org/pub/rocky/${ver}"
  log "Mirroring images/ for ${ver}/${arch} ..."
  mkdir -p "${MIRROR_DIR}/${ver}/images/${arch}/"
  wget -q -e robots=off --mirror --no-parent --no-host-directories \
       --directory-prefix="${MIRROR_DIR}/${ver}/images/${arch}/" \
       "${base}/images/${arch}/" || log "images/ not present for ${ver}/${arch}; skipping."
  log "Mirroring isos/ for ${ver}/${arch} ..."
  mkdir -p "${MIRROR_DIR}/${ver}/isos/${arch}/"
  wget -q -e robots=off --mirror --no-parent --no-host-directories \
       --directory-prefix="${MIRROR_DIR}/${ver}/isos/${arch}/" \
       "${base}/isos/${arch}/" || log "isos/ not present for ${ver}/${arch}; skipping."
}

main() {
  command -v dnf >/dev/null || { echo "dnf missing"; exit 1; }
  command -v reposync >/dev/null || { echo "dnf-plugins-core (reposync) missing"; exit 1; }
  command -v curl >/dev/null || { echo "curl missing"; exit 1; }
  command -v wget >/dev/null || { echo "wget missing"; exit 1; }

  for ver in "${VERSIONS[@]}"; do
    for arch in "${ARCHES[@]}"; do
      log "=== Rocky Linux ${ver} (${arch}) ==="
      repos=("${REPOS_COMMON[@]}")
      if [[ "$ver" -eq 8 ]]; then
        repos+=("$REPO_8_ONLY")
      else
        repos+=("$REPO_9P_ONLY")
      fi

      for repoid in "${repos[@]}"; do
        if probe_repo "$ver" "$repoid" "$arch"; then
          reposync_one "$ver" "$arch" "$repoid"
        else
          log "Skipping ${ver}/${repoid} (${arch}) – repodata not found."
        fi
      done

      # comment this out if you don't need PXE/ISOs mirrored
      sync_images_isos "$ver" "$arch"
    done
  done

  log "Done. Output at ${MIRROR_DIR}"
}

main "$@"
