# Toolchain persistence + Lean iteration — for agents and CI

**Why this file exists:** every fresh OpenHands agent sandbox (and any fresh
CI runner) currently pays the same cold-start cost: `curl elan` + `elan
toolchain install` + `lake exe cache get` (a GB-scale Mathlib download). In
practice an agent spends 5-15 minutes before it can type-check a single file,
and on some sandboxes the toolchain is wiped between sessions. This page
documents the two free, standard answers — a **warm ghcr image** and a **CI
toolchain cache** — plus the **leancheck** iteration tool that makes the
edit→check→fix loop fast once the toolchain is warm.

---

## 1. Persisting the toolchain (free)

The repo already does the *right* thing for correctness: every cold start
fetches from the **community Mathlib olean cache** (`lake-build.azureedge.net`)
using the pins in `lean/lean-toolchain` and `lean/lakefile.lean`. The only
repeat cost an agent pays is:

1. elan itself (small, ~seconds),
2. the Lean toolchain binary (`~/.elan`),
3. the Mathlib olean cache into `lean/.lake` (the big one, ~GBs).

### 1a. Warm ghcr image (the primary answer — free for public repos)

**What:** `.github/workflows/warm-toolchain.yml` builds a **multi-stage
Docker image** (`.devcontainer/Dockerfile.warm`) on every push to `main` and
pushes it to **GitHub Container Registry**:

```
ghcr.io/allenpd728/pleanp:main          # rolling
ghcr.io/allenpd728/pleanp:lean-<sha>    # per-commit
```

The image bakes in: Ubuntu + elan + the pinned Lean toolchain **and** a warm
`lean/.lake` (Mathlib oleans fetched once at build time). Pulling the image
then gives a fully warm toolchain — **no elan install, no toolchain download,
no olean fetch** beyond `docker pull` itself.

**For an agent:** in a sandbox with Docker (or any container host):

```bash
docker pull ghcr.io/allenpd728/pleanp:main
docker run --rm -v "$PWD":/workspaces/PleaNP \
    -it ghcr.io/allenpd728/pleanp:main
# inside: cd /workspaces/PleaNP/lean && lake build <module>   # warm, seconds
```

Because GitHub Packages are unlimited/free for public images and the image
layer-caches across pulls, this is effectively zero-cost and the closest thing
to "the toolchain persists" without hosting anything.

### 1b. CI toolchain cache (secondary, for GitHub Actions itself)

The same workflow adds an `actions/cache` step for `~/.elan`, keyed by the
toolchain pin, so GitHub Actions runners restore elan+Lean in seconds on
cache hits instead of re-installing. (The Mathlib oleans are already cached
by the Azure CDN; `lake exe cache get` is fast once elan exists.)

### 1c. When to use which

| Situation | Use |
|---|---|
| Agent sandbox with Docker | pull `ghcr.io/...:main` (warm image) |
| GitHub Actions runner | `actions/cache` on `~/.elan` (auto, no action needed) |
| Local devcontainer | `.devcontainer/` (existing) — `postCreateCommand` fetch is a no-op on a warm mount |
| No Docker available | `curl elan + elan install + lake exe cache get` (the fallback AGENTS.md documents) |

**Caveat:** the warm image is a *cache snapshot*, not the source of truth —
the pins (`lean-toolchain`, `lakefile.lean`) remain authoritative. The image
is rebuilt on every `main` push precisely so it cannot drift from them.

---

## 2. Making proof search / Lean authoring faster to iterate

The single biggest iteration cost in formalization is the **edit→typecheck
loop**: running `lake env lean <file>` and parsing a wall of output to find
the one error you meant to fix.

### `tooling/leancheck.py` — first-error typechecker

```bash
# from lean/ (the lake root)
python3 ../tooling/leancheck.py PleaNP/Barriers/DiagonalUB.lean
```

prints only:

```
ERROR PleaNP/Barriers/DiagonalUB.lean:12:7:
  <the error line>
  <a compact slice of the goal context>
hint: typeclass synthesis failed (missing instance?)
      common fixes: unfold ... / add [simp] / use `erw` or `change`
(2 error(s), 1 warning(s); use --all to list every error)
```

Flags: `--all` (every error), `--no-context`, `--json` (machine-readable for
agent scripts). Exit codes: 0 clean, 1 errors, 2 toolchain-missing/timeout.
Stdlib-only, CI-safe.

### `tooling/watch_leancheck.py` — poll until clean

For long proof sessions (or an auto-saving editor):

```bash
python3 ../tooling/watch_leancheck.py PleaNP/Barriers/DiagonalUB.lean
```

re-checks every 0.5s and **stops the moment the file type-checks**, printing
iterations + elapsed. Ctrl-C gives a final check so you always see the last
state.

**Why this accelerates proof search:** the proof-authoring loop is dominated
by "read the error, fix, re-check." Warm toolchain + first-error parsing cuts
each iteration from minutes to seconds, which matters most in the
long-tactic-chains proof work (e.g. the U_B machine construction in
`DiagonalUB.lean`).

---

## 3. Adoption checklist

- [ ] CI builds+pushes `ghcr.io/...:main` on `main` (workflow lands in repo).
- [ ] `tooling/leancheck.py` + `watch_leancheck.py` committed + tested
      (parser unit-verified; live `lake` run needs a warm sandbox).
- [ ] AGENTS.md "Build and test" section points agents at the warm image as
      the preferred cold-start path.
- [ ] An agent session adopts `leancheck.py` for its proof work (trial).

---

## 4. Cost note

All of the above runs on services that are **free** for a public repo:
GitHub Actions (public-repo minutes), GitHub Container Registry (public
images, no storage charge), and the community Mathlib Azure CDN (donated to
the Lean community). There is no self-hosted service to run or pay for; the
design leans entirely on existing free infrastructure plus a small amount of
workflow glue.