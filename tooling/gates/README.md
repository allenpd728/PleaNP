# Integrity gates: Tier 1 scanners

Part of the integrity pipeline (`docs/ARCHITECTURE.md`). These Python scanners catch mechanical integrity failures that a grep/AST pass can detect — they need no Lean toolchain and run in the remote authoring environment and in CI. Each is the Tier 1 of its gate; the full gate (Tier 2, requiring `lake build`) is the local agent's job.

## Gate 6 — Hygiene scanner (`hygiene_scan.py`)

Scans for proof-shortcut tokens: `sorry`, `admit`, custom `axiom`, `by decide`/`by exact?` abuse, `irreducible`. Two modes: render-stage (a single `:= by sorry` placeholder allowed during statement rendering) and `--prove-stage` (any `sorry` is a violation once a proof is claimed complete). **Does not catch** `sorry` smuggled via meta-programs — that is Tier 2 (`hygiene_axioms.lean`, `#print axioms`, local agent's job).

## Gate 5 — Vacuity / non-triviality scanner (`vacuity_scan.py`)

Scans for the **dishonest placeholder** pattern: definitions/theorems whose bodies are vacuously true or trivially constructed — "compiles but means nothing." This is the gap Gate 6 doesn't cover: a `sorry` is *honest* (it admits incompleteness), but a `theorem ... : True := by trivial` or `def ... := ∀ x, x ∈ L ↔ True` is a *fake success* that passes hygiene clean. Catches:

- `theorem`/`lemma` with `: True := by trivial` (or `rfl`/`decide`) — a real-looking theorem proving a triviality. Does NOT flag `: True := by sorry` (that's an honest render-stage placeholder, caught by Gate 6).
- `def` with `↔ True` in the body — vacuous equivalence (the `DecidesInTime := ∀ x, x ∈ L ↔ True` pattern).
- `def` with `:= True` — bare equality to True.
- `def` with `:= none` — constant failure masquerading as an implementation (the `stepCountByEvalsToInTime ... := none` pattern).

**Does NOT catch** vacuity that requires understanding what a definition *means* (e.g. a real-looking but subtly-wrong predicate) — that is Gate 4 (read-back) and the review layer's job. "Gate 5 passed" = Tier 1 + review, not Tier 1 alone.

## Gate 2 — Model-consistency scanner (`model_consistency_scan.py`)

Scans for local redefinitions of canonical types and forbidden namespace usage — the "redefine NP weaker and prove the redefined thing" failure mode (Pattern A, Gate 2 in `docs/ARCHITECTURE.md`). Checks:

- Local `def`/`abbrev`/`notation` of complexity-class names (`P`, `NP`, `PSPACE`, `Oracle`, etc.) *outside* the `PleaNP.*` namespace — these should be imported from upstream (DEC-003) or defined under `PleaNP.*`, not as bare top-level names. Tracks namespace context (including nested namespaces inside docstring blocks) so qualified `PleaNP.Oracles.Oracle` defs are NOT false-flagged.
- Usage of the `Complexity.*` namespace — forbidden per DEC-002.

**Does NOT catch** a subtly-weaker redefinition using a different name (e.g. `def MyNP := ...`) — that is Gate 4 (read-back) and the review layer's job. "Gate 2 passed" = Tier 1 + review.

## Two tiers (different agents, different trust boundaries)

Both gates are implemented in two tiers, because the sneaky cases require the Lean toolchain:

### Tier 1 — Python scanners (this directory, present)

`hygiene_scan.py` (Gate 6) and `vacuity_scan.py` (Gate 5). No Lean toolchain needed — they read source as text/AST. Run in the remote authoring environment and in CI. **Deliberately partial**: they catch the mechanical patterns, not the semantic ones.

### Tier 2 — Lean-dependent checks (local agent's job)

- Gate 6 Tier 2 (`hygiene_axioms.lean`, spec): `#print axioms` on each frozen statement, checking the axiom set is exactly Mathlib's standard. Catches sorry-smuggled-via-meta. complexitylib's `AxiomGuard` is the prior art.
- Gate 5 Tier 2: (future) a Lean-dependent check that a statement isn't vacuous under the chosen axioms — requires evaluating the statement's semantic content, which needs the Lean kernel.

## What the gates accept / reject

- **Accept:** a frozen statement whose only `sorry` is the render-stage placeholder (Gate 6) and whose definitions have real (non-vacuous) bodies (Gate 5).
- **Reject:** any `sorry`/`admit` in a proven theorem (Gate 6); any `theorem : True := by trivial` or `def := ∀ ... ↔ True` or `def := none` (Gate 5).
- **Flag (not auto-reject):** `by decide` / `by exact?` (Gate 6 smell); `irreducible` (Gate 6 review).

## Scope honesty

Tier 1 alone is **not Gate 5/6 complete.** Treating a grep pass as "Gate passed" is itself an integrity hole. The gates are "passed" only when *both* tiers run. The remote authoring agent's role is to ship Tier 1 and the Tier 2 specs; the local agent completes Tier 2.

## CI enforcement (2026-08-18)

Gate 6 Tier 1 (the hygiene scanner) is enforced in CI via `.github/workflows/ci.yml`, which runs `hygiene_scan.py --prove-stage` on every push/PR to main. Additionally, per-file `set_option warningAsError true` pragmas in PleaNP .lean files make `sorry` a hard build failure.

Gate 5 Tier 1 (the vacuity scanner) should be added to CI alongside the hygiene scanner (run `python3 tooling/gates/vacuity_scan.py lean/PleaNP` in the same workflow). This is a pending CI update — see `docs/STATEMENTS/HygieneEnforcement.spec.md`.

Note: this enforces Tier 1 (grep/AST-scannable patterns) only. Tier 2 (`#print axioms`; semantic vacuity) is still the local agent's separate job. "CI green" is necessary, not sufficient, for "Gate 5/6 passed."

## Gate 7 (Tier 1): binder usage / lethality scanner (2026-08-18)

`binder_usage_scan.py` checks that every named parameter, field, and
bound variable in a definition is load-bearing (actually used in the
body). Catches:
- Unused definition parameters (Flaw A shape)
- Declarations never applied / fields never read (Flaw B shape)
- Bound variables absent from their own conjunct (Flaw C shape)

Usage: `python3 binder_usage_scan.py lean/PleaNP`

See `docs/VALIDATION_SUITE.md` for the full validation requirements.
