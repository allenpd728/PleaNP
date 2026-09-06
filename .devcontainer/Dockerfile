# PleaNP devcontainer — persistent Lean 4 + Mathlib environment.
#
# DEC-013 (Plan A): a warm, reproducible dev environment for humans (VS Code in
# the browser via GitHub Codespaces / Gitpod) and for agents. Persistence comes
# from this image + the community Mathlib olean cache (`lake exe cache get`),
# NOT from any live machine. Building Mathlib from source never happens here.
#
# The toolchain is pinned by lean/lean-toolchain; the mathlib version by
# lean/lakefile.lean. Bump both together (see docs/UPSTREAM_TRACKING.md).

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git python3 && \
    rm -rf /var/lib/apt/lists/*

# elan (Lean version manager) — matches repo CI exactly.
RUN curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh -s -- -y --default-toolchain none && \
    /root/.elan/bin/elan --version

ENV PATH="/root/.elan/bin:${PATH}"

# Vanilla image: the repo is mounted at /workspaces/PleaNP by the devcontainer
# framework; `lake exe cache get` + `lake build` run in postCreateCommand (see
# devcontainer.json) so this image stays small and cache/distro-agnostic.