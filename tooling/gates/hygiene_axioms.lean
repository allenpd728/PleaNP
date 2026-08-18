/-!
# Gate 6 (Tier 2) — axiom-tracking hygiene (LOCAL AGENT'S JOB)

This is a *spec*, not an implementation. It requires `lake build` and the
Lean toolchain, so it is the local agent's responsibility per DEC-007 and
`docs/STATEMENTS/LOCAL_AGENT_WORKFLOW.md`. The remote authoring agent
(Tier 1, `hygiene_scan.py`) cannot run Lean.

## What Tier 2 catches that Tier 1 cannot

`hygiene_scan.py` (Tier 1) greps source for literal `sorry`/`admit`/`axiom`.
It CANNOT catch:

- **`sorry` smuggled via a meta-program.** A custom tactic can internally
  invoke `sorry` (e.g. `elaborator`/`macro` that synthesizes a sorry term).
  The call site shows only the tactic name, not `sorry`. This is the exact
  sneaky case `docs/FAILURE_AUDIT.md` Pattern C names.
- **A proof that uses a custom axiom declared elsewhere** (in a dependency,
  or transitively).
- **`admit` introduced via `Option`/`Quot`-flavored construction.**

## What the local agent builds

For each frozen statement (`docs/STATEMENTS/*.md` rendered into `lean/`),
run Lean's axiom inspection on the proof term:

```lean
-- For each frozen theorem T:
#print axioms T
```

The output is the set of axioms the proof depends on. The acceptance rule:

- **Accept** iff the axiom set is exactly the agreed Mathlib-standard set:
  `{propext, Classical.choice, Quot.sound}` (the three Mathlib axioms the
  project trusts by default). No custom axioms, no `sorry`-derived axioms.
- **Reject** if the set contains anything else — most importantly
  `PleaNP.sorryAx` or any `axiom` declared outside Mathlib core.

## Prior art

complexitylib's `AxiomGuard` (`docs/UPSTREAM_TRACKING.md` §6) is the
reference implementation — a script that mechanically guards headline
results against hidden axioms. The local agent should consult it before
re-implementing.

## How the two tiers compose

A statement is "Gate 6 passed" only when BOTH tiers run:
- Tier 1 (`hygiene_scan.py`): no literal sorry/admit outside the allowed
  render-stage placeholder, no custom axiom declarations in source.
- Tier 2 (this file, `#print axioms`): the proof's axiom set is exactly
  the trusted standard set.

Tier 1 is a fast pre-check that catches the obvious cases; Tier 2 is the
trust anchor that catches the sneaky ones. Neither alone is sufficient.
-/
