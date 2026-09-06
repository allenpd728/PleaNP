# DEC-013 activation checklist (human owner)

**Status:** 2026-09-06, updated after billing cleared — Plan B (CI) **verified green live** (run on `459d38c`: success in ~2 min, 15:11:25-15:13:28 UTC). Plan A (Codespace) needs the owner web-UI click or a token with Codespaces admin scope — the repo-scope token cannot create Codespaces ("Must have admin rights" on POST /user/codespaces).

This is the owner's to-do list for finishing the DEC-013 landing (Plan A +
Plan B). Everything listed under "Already automated" is committed and pushed;
everything under "Blocked on owner" needs the GitHub account owner.

---

## Context: why this list exists

DEC-013 (docs/decisions/LOG.md) proposed two persistence mechanisms for the
Lean 4 + Mathlib toolchain, both free and public:

- **Plan B** — GitHub Actions as the repo's always-free "build oracle"
  (gates on the clean modules; restores the Mathlib olean cache).
- **Plan A** — a devcontainer so Codespaces/Gitpod give a warm browser-based
  environment (elan + cache + lean4 extension), no Mathlib-from-source ever.

Both were implemented and pushed (commits `55329e6` + `68f3ba1`). Verification
in-sandbox (ubuntu container, same commands as CI) passes clean:
`elan install` → `lake exe cache get` → `lake build PleaNP.Basic
PleaNP.Calculus.BarrierCalculus` → all four `#barrier_check` verdicts correct.

The billing lock (account-level) was the CI blocker; it is now resolved and
CI is green. Codespace creation remains blocked on token *scope* (needs
`admin:codespaces` or a web-UI click), not billing. Evidence (2026-09-06):
- Latest Actions run (`34033388621`, attempts 1-3) annotation: *"The job was
  not started because your account is locked due to a billing issue."*
- `POST /user/codespaces` with the repo-owner token → HTTP 500.
- `GET /user/billing` → 404 (token has `repo` scope, not billing scope).

---

## Already automated (nothing to do)

- [x] `.devcontainer/Dockerfile` + `.devcontainer/devcontainer.json`
   (elan, lean4 VS Code extension, `lake exe cache get` +
   `lake build` of the clean modules on create/start).
- [x] `.github/workflows/ci.yml` — Mathlib olean cache-restore step; builds
   `PleaNP.Basic` + `PleaNP.Calculus.BarrierCalculus` (full-tree `lake build`
   stays deferred until the v3 `Oracle.lean` debt is repaired — see
   SORRY_TRACKER); runs hygiene/vacuity/model/binder scanners.
- [x] DEC-013 status flips `Proposed → Active`; AGENTS.md file map and
   `docs/TOOLCHAIN_SOLUTIONS.md` reference the landing.
- [x] Verified in-sandbox: the exact CI step sequence is green.

---

## Blocked on owner (the only remaining steps)

### 1. Resolve the GitHub billing lock (blocks BOTH B and A)
- Do: GitHub → your profile → **Settings → Billing and plans** (or the banner
  on the Actions tab). Bring the account current (or re-confirm payment
  method / plan) so Actions and Codespaces can start jobs.
- This is required before ANY of the below will work; it is not automatable
  with the tokens available (they lack billing/admin scope).

### 2. After the lock clears — confirm CI is green (Plan B)
- Nothing to build; just let the next push/PR run. To trigger a check run
  with no new work, any agent can re-run the last failed job:
  `POST /repos/{owner}/{repo}/actions/runs/{run_id}/rerun`
- Expected: `install elan` → `lake exe cache get` (a few min) → `lake build`
  of the two clean modules → scanner steps → all green (~total < 10 min).

### 3. After the lock clears — create the Codespace once (Plan A)
- One-time, browser-clickable: repo → **Code → Codespaces →
  "Create codespace on main"**. First boot pulls the devcontainer +
  Mathlib cache (~5-10 min); after that every session is warm.
- (Optionally) agents can instead call `POST /user/codespaces` with a repo
  token once billing is healthy (currently HTTP 500 due to the lock).

### 4. Optional follow-ups (not blocking)
- Widen CI back to the full-tree `lake build` when the v3 `Oracle.lean` debt
  is repaired (Oracle.v4-repair.spec.md).
- If Codespaces/CI minutes are ever a concern, Gitpod (50 h/mo) is the
  drop-in alternative; lean4web playgrounds cover single-file experiments.

---

## Verification notes (how to check without special access)

- CI status: `GET /repos/allenpd728/PleaNP/actions/runs?per_page=5` (public)
  or the Actions tab. Look for `conclusion: success` on `main`.
- Codespace: `GET /user/codespaces` with a repo token once created, or just
  the Codespaces tab.
- In-repo signals that everything landed:
  - `git log --oneline -3` shows `55329e6 ci: activate DEC-013…`
  - `.devcontainer/` and the CI cache-restore step exist on `main`.