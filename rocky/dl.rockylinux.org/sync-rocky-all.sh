#!/usr/bin/env bash
set -euo pipefail

# === Config (env-overridable) ================================================
MIRROR_DIR="${MIRROR_DIR:-/rocky-mirror}"
ARCH="${ARCH:-x86_64}"
VERSIONS=(${VERSIONS:-8 9 10})

# Primary public mirror + vault base (used only if enabled below)
BASE="${BASE:-https://dl.rockylinux.org}"
PUB="${PUB:-$BASE/pub/rocky}"
VAULT="${VAULT:-$BASE/vault/rocky}"

# If you want frozen 8.x content, set e.g. VAULT_8="8.9" (empty => use PUB)
VAULT_8="${VAULT_8:-}"

# ============================================================================

log() { printf "[%s] %s\n" "$(date +'%F %T')" "$*"; }

# Return the baseurl for a repo/version/arch, honoring vault for 8 if configured
repo_baseurl() {
  local ver="$1" repo="$2" arch="$3"

  # Choose tree root: VAULT for 8 if VAULT_8 is set; otherwise PUB
  local root
  if [[ "$ver" -eq 8 && -n "$VAULT_8" ]]; then
    root="${VAULT}/${VAULT_8}"
  else
    root="${PUB}/${ver}"
  fi

  # Standard DNF repo layout
  printf "%s/%s/%s/os/" "$root" "$repo" "$arch"
}

# Probe a DNF repo by checking repodata/repomd.xml (follow redirects)
probe_repo() {
  local baseurl="$1"
  curl -fsL -o /dev/null "${baseurl}repodata/repomd.xml"
}

# Repos to try per version (handles PowerTools vs CRB)
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

  # images/
  log "Syncing images/ for Rocky ${ver} (${arch}) ..."
  rsync -av --delete --partial \
    "${src_root}/images/${arch}/" \
    "${dst_root}/images/${arch}/" || log "images/ not present for ${ver}/${arch}; skipping."

  # isos/
  log "Syncing isos/ for Rocky ${ver} (${arch}) ..."
  rsync -av --delete --partial \
    "${src_root}/isos/${arch}/" \
    "${dst_root}/isos/${arch}/" || log "isos/ not present for ${ver}/${arch}; skipping."
}

sync_version() {
  local ver="$1"
  log "=== Rocky Linux ${ver} ==="

  mkdir -p "${MIRROR_DIR}/${ver}"
  local tmp_repo="/tmp/rocky${ver}.repo"
  : > "$tmp_repo"

  # Build repo list and add only those that probe successfully
  local repo baseurl
  while read -r repo; do
    baseurl="$(repo_baseurl "$ver" "$repo" "$ARCH")"
    if probe_repo "$baseurl"; then
      log "Enabling ${ver}/${repo} (${ARCH})"
      cat >> "$tmp_repo" <<EOF
[${repo,,}]
name=Rocky Linux ${ver} - ${repo}
baseurl=${baseurl}
enabled=1
gpgcheck=0

EOF
    else
      log "Skipping ${ver}/${repo} (${ARCH}) – repodata not found."
    fi
  done < <(repos_for_ver "$ver")

  # Run reposync for all enabled repos
  local repo_ids
  repo_ids=$(grep -E '^\[[^]]+\]' "$tmp_repo" | tr -d '[]' || true)
  if [[ -n "$repo_ids" ]]; then
    log "reposync: $repo_ids"
    # shellcheck disable=SC2046
    dnf reposync \
      $(echo "$repo_ids" | awk '{for(i=1;i<=NF;i++) printf "--repoid=%s ", $i}') \
      --download-metadata \
      --download-path="${MIRROR_DIR}/${ver}" \
      --config="$tmp_repo" \
      --arch="${ARCH}"
  else
    log "No DNF repos enabled for Rocky ${ver} (${ARCH})."
  fi

  # Sync images/ and isos/
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
