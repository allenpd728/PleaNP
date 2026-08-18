# Gate 6 — Hygiene scanner

Part of the integrity pipeline (`docs/ARCHITECTURE.md`). Gate 6 scans formal Lean source for proof-shortcut tokens that would make a "proof" compile without being a real proof. A "proof" that compiles only because it hides an unproven step is exactly the failure mode this gate blocks (`docs/FAILURE_AUDIT.md` Pattern A/C).

## Two tiers (different agents, different trust boundaries)

Gate 6 is implemented in two tiers, because the sneaky cases require the Lean toolchain:

### Tier 1 — `hygiene_scan.py` (this directory, present)

A Python text scanner. Flags the literal proof-shortcut tokens in `.lean` source:
- `sorry` — the canonical unproven-step marker
- `admit` — synonym for `sorry`
- `axiom` / `constant` (used as an axiom declaration, not the keyword inside a doc comment)
- `by decide` / `by exact?` abuse — heuristic, see below
- `irreducible` sometimes used to hide a sorry behind a definition

**It needs no Lean toolchain** — it reads source as text. This means it can run in the remote authoring environment. **It is deliberately partial**: it cannot catch `sorry` smuggled in via a meta-program (a custom tactic that internally calls `sorry`), because that does not appear as a literal token at the call site. Tier 1 is a *first line of defense*, not the complete gate.

### Tier 2 — `hygiene_axioms.lean` (this directory, stub — local agent's job)

The complete gate requires Lean's own machinery: running `#print axioms <theorem>` on each frozen statement and checking the axiom set is exactly `{propext, Classical.choice, Quot.sound}` (Mathlib's standard axiom set) — or whatever set the project has agreed to trust. Custom axioms or a `sorry` smuggled via meta appear here. complexitylib's `AxiomGuard` (`docs/UPSTREAM_TRACKING.md` §6) is the prior art for this.

**Tier 2 needs `lake build` and is therefore the local agent's responsibility** (per `docs/STATEMENTS/LOCAL_AGENT_WORKFLOW.md` and DEC-007). The local agent writes the `#print axioms` runner and reports the trusted-axiom set; the remote authoring agent does not run Lean.

## What the gate accepts / rejects

- **Accept:** a frozen statement whose only `sorry`/`admit` is the proof-search placeholder (per `LOCAL_AGENT_WORKFLOW.md` Step 1 — a `theorem ... := by sorry` placeholder is expected during rendering and is not a violation *at the statement-freeze stage*; it becomes a violation once the statement is frozen and proof search claims completion).
- **Reject:** any `sorry`/`admit` in a *proven* theorem, any custom `axiom`, or any `sorry` appearing in a proof that is claimed complete.
- **Flag (not auto-reject):** `by decide` / `by exact?` — these are legitimate tactics, but heavy use to close hard goals is a smell; the gate reports counts for human review.

## Scope honesty

Tier 1 alone is **not Gate 6 complete.** Treating a grep pass as "Gate 6 passed" is itself an integrity hole (it would miss the meta-smuggled case — the exact sneaky failure the audit names). The gate is "passed" only when *both* tiers run. The remote authoring agent's role is to ship Tier 1 and the Tier 2 spec; the local agent completes Tier 2.


## CI enforcement (2026-08-18)

Gate 6 Tier 1 (the hygiene scanner) is now enforced in CI via
`.github/workflows/ci.yml`, which runs `hygiene_scan.py --prove-stage`
on every push/PR to main. Additionally, per-file `set_option warningAsError true`
pragmas in PleaNP .lean files make `sorry` a hard build failure.

Note: this enforces Tier 1 (grep-scannable sorry/admit/axiom) only.
Tier 2 (`#print axioms` for sorry-smuggled-via-meta) is still the local
agent's separate job. "CI green" is necessary, not sufficient, for
"Gate 6 passed." See `docs/STATEMENTS/HygieneEnforcement.spec.md` for
the full spec.
