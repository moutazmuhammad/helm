#!/usr/bin/env bash
# =============================================================================
# Mirror SeaweedFS chart images into the internal Artifact Registry.
#
# Source -> destination map (see the IMAGES array below). Each entry copies
# upstream:tag verbatim into:
#   europe-west1-docker.pkg.dev/vf-grp-aib-dev-mirror/aib-plus-images/<short>:<tag>
#
# Usage:
#   ./scripts/mirror-seaweedfs-images.sh                # mirror all
#   ./scripts/mirror-seaweedfs-images.sh --dry-run      # show actions, no push
#   ./scripts/mirror-seaweedfs-images.sh --force        # repush even if dest exists
#   DEST_REGISTRY=foo.example.com/bar ./scripts/mirror-seaweedfs-images.sh
#
# Tooling:
#   - Prefers `crane` (https://github.com/google/go-containerregistry) — copies
#     manifests directly between registries without a local Docker daemon, so
#     it preserves multi-arch indexes correctly.
#   - Falls back to `docker pull/tag/push` if crane is missing.
#
# Auth:
#   - You must be authenticated to push to the destination Artifact Registry.
#     For GCP/GAR, the typical setup is:
#       gcloud auth login
#       gcloud auth configure-docker europe-west1-docker.pkg.dev --quiet
# =============================================================================

set -euo pipefail

DEST_REGISTRY="${DEST_REGISTRY:-europe-west1-docker.pkg.dev/vf-grp-aib-dev-mirror/aib-plus-images}"

# source-image                        short-name      tag
IMAGES=(
  "docker.io/chrislusf/seaweedfs      seaweedfs       4.21"
  "docker.io/alpine/k8s               alpine-k8s      1.28.4"
)

DRY_RUN=0
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --force)   FORCE=1 ;;
    -h|--help)
      sed -n '2,/^# ===/p' "$0" | sed 's/^# \{0,1\}//' ; exit 0 ;;
    *) echo "Unknown flag: $arg" >&2; exit 2 ;;
  esac
done

# -----------------------------------------------------------------------------
# Detect transfer tool
# -----------------------------------------------------------------------------
if command -v crane >/dev/null 2>&1; then
  TOOL=crane
elif command -v docker >/dev/null 2>&1; then
  TOOL=docker
else
  echo "ERROR: neither 'crane' nor 'docker' is on PATH. Install one and retry." >&2
  echo "  brew install crane            # or" >&2
  echo "  go install github.com/google/go-containerregistry/cmd/crane@latest" >&2
  exit 1
fi
echo "Using transfer tool: $TOOL"
echo "Destination prefix : $DEST_REGISTRY"
echo

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
dest_exists() {
  local image="$1"
  if [[ "$TOOL" == "crane" ]]; then
    crane manifest "$image" >/dev/null 2>&1
  else
    docker manifest inspect "$image" >/dev/null 2>&1
  fi
}

copy_image() {
  local src="$1" dst="$2"
  if [[ "$TOOL" == "crane" ]]; then
    crane copy "$src" "$dst"
  else
    docker pull "$src"
    docker tag  "$src" "$dst"
    docker push "$dst"
  fi
}

# -----------------------------------------------------------------------------
# Main loop
# -----------------------------------------------------------------------------
copied=0
skipped=0
failed=0

for entry in "${IMAGES[@]}"; do
  read -r src_repo short tag <<<"$entry"
  src="${src_repo}:${tag}"
  dst="${DEST_REGISTRY}/${short}:${tag}"

  printf '  %-45s -> %s\n' "$src" "$dst"

  if (( DRY_RUN )); then
    skipped=$((skipped + 1))
    continue
  fi

  if (( ! FORCE )) && dest_exists "$dst"; then
    echo "    [skip] already present in destination"
    skipped=$((skipped + 1))
    continue
  fi

  if copy_image "$src" "$dst"; then
    echo "    [ok] copied"
    copied=$((copied + 1))
  else
    echo "    [FAIL] copy returned non-zero" >&2
    failed=$((failed + 1))
  fi
done

echo
echo "Summary: copied=$copied  skipped=$skipped  failed=$failed"
(( failed == 0 ))
