#!/usr/bin/env bash
# elantool.sh — warm-Lean launcher for PleaNP agents and humans.
#
# Strategy (Plan E, docs/TOOLCHAIN_AGENTS.md):
#   1. If a local copy of the warm ghcr image exists, run `lake ...` inside an
#      ephemeral container that mounts the repo — no elan install, no toolchain
#      download, no Mathlib olean fetch.
#   2. If the image is not local but Docker is available, `docker pull` it once
#      (free, public) and reuse layers on subsequent runs.
#   3. If Docker is unavailable, fall back to the AGENTS.md curl-bootstrap that
#      installs elan + Lean + fetches the Mathlib olean cache into lean/.lake.
#
# Usage (from the repo root):
#   tooling/elantool.sh lake build PleaNP.Barriers.DiagonalUB
#   tooling/elantool.sh lake env lean PleaNP/Barriers/DiagonalUB.lean
#   tooling/elantool.sh shell            # drop into an interactive container
#   tooling/elantool.sh pull             # just pull/refresh the warm image
#
# Exit codes: 0 success, 3 no method available, 2 command failed inside sandbox.
#
# All paths are relative to the repo root; the container mounts $PWD at
# /workspace and runs in /workspace/lean when the command is a lake cmd.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_DEFAULT="ghcr.io/philipdallen/pleanp"
IMAGE_TAG="${PLEANP_LEAN_TAG:-main}"
IMAGE="${PLEANP_LEAN_IMAGE:-${IMAGE_DEFAULT}:${IMAGE_TAG}}"
MOUNT_POINT="${PLEANP_LEAN_MOUNT:-/workspace}"

__have() { command -v "$1" >/dev/null 2>&1; }

__docker_works() {
  # Docker CLI present AND daemon reachable — a bare `docker` binary with no
  # daemon (common in sandboxes) must NOT count as working.
  __have docker && docker info >/dev/null 2>&1
}

__in_container() {
  # If we're already inside the warm image, just run the command directly.
  [ -f /workspaces/PleaNP/lean/lean-toolchain ] && return 0
  [ -f /workspace/lean/lean-toolchain ] && return 0
  return 1
}

__image_present() {
  __docker_works && docker images --format '{{.Repository}}:{{.Tag}}' | grep -qx "$IMAGE"
}

__bootstrap_cold() {
  echo "[elantool] no working docker; doing the AGENTS.md curl-bootstrap"
  export PATH="$HOME/.elan/bin:$PATH"
  if ! __have elan; then
    # Match AGENTS.md exactly: pipe the installer into `sh -s -- <args>`.
    curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh \
      | sh -s -- -y --default-toolchain none
    export PATH="$HOME/.elan/bin:$PATH"
  fi
  cd "$REPO_ROOT/lean"
  lake exe cache get     # warm Mathlib oleans (no-op if already warm)
}

__with_image() {
  echo "[elantool] running inside warm image ${IMAGE}"
  # docker run mounts the repo, sets HOME for elan under /root (image is root).
  docker run --rm \
    -v "$REPO_ROOT":"$MOUNT_POINT" \
    -w "$MOUNT_POINT/lean" \
    -e HOME=/root \
    "$IMAGE" bash -c "$*"
}

# --- command dispatch ---
cmd="${1:-}"
case "$cmd" in
  pull|refresh)
    __docker_works || { echo "[elantool] docker daemon required for pull"; exit 3; }
    docker pull "$IMAGE"
    exit 0
    ;;
  shell)
    __in_container && { echo "[elantool] already in warm image; launching bash"; exec bash; }
    if __image_present || __docker_works; then
      if ! __image_present; then
        echo "[elantool] pulling ${IMAGE}"
        docker pull "$IMAGE"
      fi
      exec docker run --rm -it -v "$REPO_ROOT:$MOUNT_POINT" -w "$MOUNT_POINT/lean" -e HOME=/root "$IMAGE" bash
    else
      __bootstrap_cold
      exec bash
    fi
    ;;
  "")
    echo "usage: $0 { lake <args...> | shell | pull }" >&2
    exit 64
    ;;
  *)
    # treat as a lake invocation: `elantool lake build X` or `elantool build X`
    if [ "$cmd" = "lake" ]; then
      shift
    fi
    if __in_container; then
      cd "$REPO_ROOT/lean"
      lake "$@"
      exit $?
    fi
    if __image_present; then
      __with_image "lake $*"
      exit $?
    fi
    if __docker_works; then
      echo "[elantool] image ${IMAGE} not local; pulling once"
      docker pull "$IMAGE"
      __with_image "lake $*"
      exit $?
    fi
    echo "[elantool] no working docker and no warm image; falling back to bootstrap"
    __bootstrap_cold
    cd "$REPO_ROOT/lean"
    lake "$@"
    ;;
esac