#!/usr/bin/env bash
set -euo pipefail

# ====================== Config (env-overridable) ======================
MIRROR_DIR="${MIRROR_DIR:-/rocky-mirror}"
ARCH="${ARCH:-x86_64}"
VERSIONS=(${VERSIONS:-8 9 10})

BASE="${BASE:-https://dl.rockylinux.org}"
PUB="${PUB:-$BASE/pub/rocky}"
VAULT="${VAULT:-$BASE/vault/rocky}"
VAULT_8="${VAULT_8:-}"   # e.g. 8.9 to freeze at vault; empty => use PUB for 8
# =====================================================================

log() { printf "[%s] %s\n" "$(date +'%F %T')" "$*"; }

# Build repo baseurl, honoring VAULT_8 for Rocky 8 if set
repo_baseurl() {
  local ver="$1" repo="$2" arch="$3"
  local root
  if [[ "$ver" -eq 8 && -n "$VAULT_8" ]]; then
    root="${VAULT}/${VAULT_8}"
  else
    root="${PUB}/${ver}"
  fi
  printf "%s/%s/%s/os/" "$root" "$repo" "$arch"
}

# Probe a DNF repo by checking repodata/repomd.xml (follow redirects)
probe_repo() {
  local baseurl="$1"
  curl -fsL -o /dev/null "${baseurl}repodata/repomd.xml"
}

# Repo set per version (includes both devel/Devel; whichever exists will sync)
repos_for_ver() {
  local ver="$1"
  local r=(BaseOS AppStream extras devel Devel plus)
  if [[ "$ver" -eq 8 ]]; then r+=(PowerTools); else r+=(CRB); fi
  printf "%s\n" "${r[@]}"
}

# Sync non-DNF trees via rsync (images/ & isos/)
sync_images_isos() {
  local ver="$1" arch="$2"
  local src_root dst_root
  if [[ "$ver" -eq 8 && -n "$VAULT_8" ]]; then
    src_root="${VAULT}/${VAULT_8}/${ver}"
  else
    src_root="${PUB}/${ver}"
  fi
  dst_root="${MIRROR_DIR}/${ver}"

  log "Syncing images/ for Rocky ${ver} (${arch}) ..."
  rsync -av --delete --partial \
    "${src_root}/images/${arch}/" \
    "${dst_root}/images/${arch}/" || log "images/ not present for ${ver}/${arch}; skipping."

  log "Syncing isos/ for Rocky ${ver} (${arch}) ..."
  rsync -av --delete --partial \
    "${src_root}/isos/${arch}/" \
    "${dst_root}/isos/${arch}/" || log "isos/ not present for ${ver}/${arch}; skipping."
}

# Reposync exactly one repo (avoid duplicate-id conflicts)
reposync_one() {
  local ver="$1" repo="$2" baseurl="$3"
  local tmp_repo="/tmp/rocky_${ver}_${repo}.repo"

  # temp empty reposdir so dnf doesn't load system /etc/yum.repos.d definitions
  local EMPTY_REPOSDIR; EMPTY_REPOSDIR="$(mktemp -d)"
  trap 'rm -rf "$EMPTY_REPOSDIR" "$tmp_repo"' RETURN

  cat > "$tmp_repo" <<EOF
[${repo}]
name=Rocky Linux ${ver} - ${repo}
baseurl=${baseurl}
enabled=1
gpgcheck=0
EOF

  mkdir -p "${MIRROR_DIR}/${ver}"
  log "reposync ${ver}/${repo} (${ARCH})"
  dnf reposync \
    --repoid="${repo}" \
    --download-metadata \
    --download-path="${MIRROR_DIR}/${ver}" \
    --config="$tmp_repo" \
    --setopt=reposdir="${EMPTY_REPOSDIR}" \
    --arch="${ARCH}"
}

sync_version() {
  local ver="$1"
  log "=== Rocky Linux ${ver} ==="

  while read -r repo; do
    local baseurl; baseurl="$(repo_baseurl "$ver" "$repo" "$ARCH")"
    if probe_repo "$baseurl"; then
      reposync_one "$ver" "$repo" "$baseurl"
    else
      log "Skipping ${ver}/${repo} (${ARCH}) – repodata not found."
    fi
  done < <(repos_for_ver "$ver")

  # Pull images/ and isos/ (non-DNF trees)
  sync_images_isos "$ver" "$ARCH"
}

main() {
  log "Starting Rocky mirror sync into ${MIRROR_DIR}"
  log "ARCH=${ARCH}  VERSIONS=${VERSIONS[*]}  PUB=${PUB}  VAULT=${VAULT}  VAULT_8=${VAULT_8:-<none>}"

  for ver in "${VERSIONS[@]}"; do
    sync_version "$ver"
  done

  log "Rocky mirror sync complete."
}

main "$@"
