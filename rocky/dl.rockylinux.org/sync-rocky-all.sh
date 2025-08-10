#!/usr/bin/env bash
set -euo pipefail

# ===== Config (override with env vars) =====
: "${MIRROR_ROOT:=/rocky-mirror}"                 # where to store the mirror (mount a volume here)
: "${VERSIONS:=8 9 10}"                     # space-separated list
: "${ARCHES:=x86_64}"                       # e.g. "x86_64 aarch64"
# User-requested repos; case-insensitive; CRB/PowerTools handled per-version below
: "${REPOS:=AppStream BaseOS Devel Extras Plus PowerTools}"
: "${UPSTREAM_BASE:=https://dl.rockylinux.org/pub/rocky}"  # official origin

# Tuning for reposync
: "${KEEP_OLD:=false}"                      # set true to skip --delete
: "${NEWEST_ONLY:=true}"                    # set false to mirror all package versions

# ===== Helpers =====
log() { printf '[%(%Y-%m-%d %H:%M:%S)T] %s\n' -1 "$*" >&2; }

# Normalize a repo token to canonical path segment (case sensitive to match upstream)
# Inputs: version, repo_token
# Echoes: canonical path segment (e.g., BaseOS, AppStream, CRB, PowerTools, extras, plus, devel)
map_repo() {
  local ver="$1" in="$2"
  local low="${in,,}"  # lowercased
  case "$low" in
    baseos)      echo "BaseOS" ;;
    appstream)   echo "AppStream" ;;
    extras)      echo "extras" ;;
    plus)        echo "plus" ;;
    devel)       echo "devel" ;;
    powertools|crb|codeready-builder)
      if [[ "$ver" == 8* ]]; then
        echo "PowerTools"
      else
        echo "CRB"
      fi
      ;;
    *)
      # Be permissive: if caller passed "Devel" or "PowerTools" with odd case, normalize known ones
      case "$in" in
        Devel) echo "devel" ;;
        PowerTools) echo "PowerTools" ;;
        CRB) echo "CRB" ;;
        Extras) echo "extras" ;;
        Plus) echo "plus" ;;
        AppStream) echo "AppStream" ;;
        BaseOS) echo "BaseOS" ;;
        *)
          log "WARN: Unknown repo '$in' for version $ver – skipping."
          return 1
          ;;
      esac
      ;;
  esac
}

# Write a minimal .repo file for a single repo+arch+version to a given path.
# Args: version repoPath arch outfile repoid
write_repo_file() {
  local ver="$1" repoPath="$2" arch="$3" out="$4" repoid="$5"
  local baseurl="${UPSTREAM_BASE}/${ver}/${repoPath}/${arch}/os/"

  cat > "$out" <<EOF
[${repoid}]
name=Rocky ${ver} ${repoPath} (${arch})
baseurl=${baseurl}
enabled=1
gpgcheck=0
repo_gpgcheck=0
metadata_expire=120m
EOF
}

# Run reposync once for a given repo/config
# Args: repoid dest_dir repo_file arch
run_sync() {
  local repoid="$1" dest="$2" repofile="$3" arch="$4"

  mkdir -p "$dest"
  local delete_flag=()
  [[ "$KEEP_OLD" == "true" ]] || delete_flag+=(--delete)

  local newest_flag=()
  [[ "$NEWEST_ONLY" == "true" ]] && newest_flag+=(--newest-only)

  # --norepopath puts content directly into $dest instead of $dest/<repoid>/
  dnf -y reposync \
    --arch "$arch" \
    --download-metadata \
    --download-path "$dest" \
    --norepopath \
    "${delete_flag[@]}" \
    "${newest_flag[@]}" \
    --repoid "$repoid" \
    -c "$repofile"
}

# ===== Main =====
main() {
  log "Starting Rocky mirror sync"
  log "Versions: ${VERSIONS} | Arches: ${ARCHES} | Repos (requested): ${REPOS}"
  log "Mirror root: ${MIRROR_ROOT} | Upstream: ${UPSTREAM_BASE}"

  # workspace for temporary repo files
  workdir="$(mktemp -d /tmp/rocky-sync.XXXXXX)"
  trap 'rm -rf "$workdir"' EXIT

  for ver in $VERSIONS; do
    for arch in $ARCHES; do
      for token in $REPOS; do
        repoPath="$(map_repo "$ver" "$token" || true)"
        [[ -n "${repoPath:-}" ]] || continue

        # Build repoid & paths
        repoid="rocky-${ver}-${repoPath}-${arch}"
        repofile="${workdir}/${repoid}.repo"
        dest="${MIRROR_ROOT}/rocky/${ver}/${repoPath}/${arch}/os"

        log "Sync: ver=${ver} repo=${repoPath} arch=${arch}"
        write_repo_file "$ver" "$repoPath" "$arch" "$repofile" "$repoid"
        run_sync "$repoid" "$dest" "$repofile" "$arch"

        # Safety: ensure repodata exists (reposync --download-metadata should have done this)
        if [[ ! -d "${dest}/repodata" ]]; then
          log "INFO: repodata missing for ${repoid}, generating with createrepo_c --update"
          createrepo_c --update "${dest}"
        fi
      done
    done
  done

  log "Completed Rocky mirror sync"
}

main "$@"
