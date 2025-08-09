#!/usr/bin/env bash
set -euo pipefail

MIRROR_DIR="/rocky-mirror"
ARCH="x86_64"
VERSIONS=(8 9 10)

REPOS_COMMON=(
  AppStream
  BaseOS
  Devel
  devel
  extras
  images
  isos
  plus
)

log() { echo "[$(date +'%F %T')] $*"; }

probe_repo() {
  local baseurl="$1"
  curl -s --head "$baseurl" | head -n 1 | grep -q "200 OK"
}

for ver in "${VERSIONS[@]}"; do
  log "=== Rocky Linux ${ver} ==="

  TMP_REPO="/tmp/rocky${ver}.repo"
  : > "$TMP_REPO"

  # Add common repos
  for repo in "${REPOS_COMMON[@]}"; do
    baseurl="https://dl.rockylinux.org/pub/rocky/${ver}/${repo}/${ARCH}/os/"
    if probe_repo "$baseurl"; then
      cat >> "$TMP_REPO" <<EOF
[${repo,,}]
name=Rocky Linux ${ver} - ${repo}
baseurl=${baseurl}
enabled=1
gpgcheck=0

EOF
    else
      log "Skipping ${repo} for Rocky ${ver} – not found."
    fi
  done

  # CRB/PowerTools handling
  if [[ "$ver" -eq 8 ]]; then
    repo="PowerTools"
    baseurl="https://dl.rockylinux.org/pub/rocky/${ver}/${repo}/${ARCH}/os/"
    if probe_repo "$baseurl"; then
      cat >> "$TMP_REPO" <<EOF
[powertools]
name=Rocky Linux ${ver} - PowerTools
baseurl=${baseurl}
enabled=1
gpgcheck=0

EOF
    fi
  else
    repo="CRB"
    baseurl="https://dl.rockylinux.org/pub/rocky/${ver}/${repo}/${ARCH}/os/"
    if probe_repo "$baseurl"; then
      cat >> "$TMP_REPO" <<EOF
[crb]
name=Rocky Linux ${ver} - CRB
baseurl=${baseurl}
enabled=1
gpgcheck=0

EOF
    fi
  fi

  # Run reposync for all enabled repos in TMP_REPO
  mkdir -p "${MIRROR_DIR}/${ver}"
  repo_ids=$(grep '^\[' "$TMP_REPO" | tr -d '[]')
  log "Syncing repos: $repo_ids"

  dnf reposync \
    $(echo "$repo_ids" | awk '{for(i=1;i<=NF;i++) printf "--repoid=%s ", $i}') \
    --download-metadata \
    --download-path="${MIRROR_DIR}/${ver}" \
    --config="$TMP_REPO" \
    --arch="${ARCH}"
done

log "Rocky mirror sync complete."
