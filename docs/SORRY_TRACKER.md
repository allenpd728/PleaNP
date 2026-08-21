# Sorry tracker: open proof/composition debts

**Purpose.** Track every `sorry` in the PleaNP Lean codebase.

**Rule:** every `sorry` in `lean/PleaNP/` must appear in this table.

**Last updated:** 2026-08-21 (v4-completion pass).

---

## Summary

| File | `sorry` count | Level |
|---|---|---|
| `lean/PleaNP/Computability/Oracle.lean` | 0 (was 1 — vacuous marker removed, see #2) | Substrate (Rung 2) |
| `lean/PleaNP/Computability/OracleComplexity.lean` | 0 (was 3) | Complexity classes (Rung 2) |
| `lean/PleaNP/Computability/OracleUpstreamP.lean` | 2 (moved from OracleComplexity) | Upstream-P anchor (Rung 2) |
| `lean/PleaNP/Barriers/Relativization.lean` | 2 | Barrier statement (Rung 3a) |
| **Total** | **4 open** (5 resolved, 1 removed) | |

All remaining sorries are honest pending proofs/compositions. The structural
self-check `P_A ⊆ NP^A` (#5a/#5b) is now proved in BOTH directions — the v4
repair is behaviorally verified by the oracle-sensitivity smoke test
(`OracleSmoke.lean`). The four remaining sorries are: upstream-P-blocked
(#6, #7 — in the isolated anchor module) and the BGS proofs (#8, #9).

`lake build` status: `Oracle.lean`, `OracleComplexity.lean`,
`OracleSmoke.lean` build green. `OracleUpstreamP.lean` (2 tracked sorries)
and `Relativization.lean` (2 tracked sorries) fail exactly on their tracked
sorries — the expected Gate-6-visible state.

Tier-2 axiom check (`#print axioms`) on the new proofs:
`evalsTo_unique_result` → {propext, Quot.sound};
`P_A_subset_NP_A`, `smoke_accepts_true`, `smoke_rejects_false` →
{propext, Classical.choice, Quot.sound}. All within the trusted
Mathlib-standard set; no `sorryAx`.

---

## Detailed inventory

### Substrate level (Oracle.lean)

| # | File:Line | What it is | Pending on | Priority |
|---|---|---|---|---|
| 2 | ~~`Oracle.lean:115`~~ **Removed** — `P_empty_eq_upstream_P` was a `True`-conclusion marker theorem whose only content was its sorry (vacuous by construction, and it blocked every `lake build` under `warningAsError`). The real tracking anchor is the class-level theorem (#6/#7), so the marker was deleted rather than left half-alive. | Upstream P (DEC-003) — now tracked only via #6/#7. | Medium |

### Complexity-class level (OracleComplexity.lean)

| # | File:Line | What it is | Pending on | Priority |
|---|---|---|---|---|
| 5a | ~~`OracleComplexity.lean`~~ **Resolved** — forward direction proved in the v4-completion pass. | — | — |
| 5b | ~~`OracleComplexity.lean`~~ **Resolved** — backward direction proved in the v4-completion pass via the new determinism lemma `Oracles.evalsTo_unique_result` (+ `step_none`) in `Oracle.lean`: the accept-run and the decide-run start from the same initial config and both halt, so they share the halted endpoint; the output bit carries over. | — | — |

### Upstream-P anchor level (OracleUpstreamP.lean, new module)

Isolated into its own leaf module so `warningAsError` does not cascade from
these two sorries into OracleComplexity and everything downstream. The
module is expected to fail the build until upstream P lands.

| # | File:Line | What it is | Pending on | Priority |
|---|---|---|---|---|
| 6 | `OracleUpstreamP.lean:25` | `P_empty_eq_upstream_P_class` — RHS set comprehension (upstream P as a set). **Statement-level sorry — Gate-5 concern** (the theorem does not yet fully say what it proves). | Upstream P (DEC-003), or an oracle-free recharacterization of the class. | High when unblocked |
| 7 | `OracleUpstreamP.lean:26` | `P_empty_eq_upstream_P_class` — proof of P^empty = P equality. | #6 + upstream P. | Medium |

### Barrier-statement level (Relativization.lean)

| # | File:Line | What it is | Pending on | Priority |
|---|---|---|---|---|
| 8 | `Relativization.lean:80` | BGS clause (a) proof — equalizing oracle existence. | #5 (done) + PSPACE/QBF + upstream P. | Low (Rung 3 Step 6) |
| 9 | `Relativization.lean:101` | BGS clause (b) proof — separating oracle existence (diagonalization). | #5 (done) + machine enumeration + diagonalization. | Low (Rung 3 Step 6) |

---

## Resolved

| # | What | Commit | Notes |
|---|---|---|---|
| 1 | `outputEncodesChi` — the per-machine output-encoding bridge | `5243a06` | Now a real predicate: `oa head = true iff x in L`. |
| 3 | `P_A` membership condition | `bc344ab` then v4 `a223b12` | Now composes `@DecidesInTime` with EvalsToInTime reachability. ea/M/t load-bearing. (hΓ added in v4 completion — see below.) |
| 4 | `NP_A` verifier condition | `bc344ab` then v4 `a223b12` | Now composes `@AcceptsInTime` on pair (x, y) with reachability. |
| 5a, 5b | `P_A_subset_NP_A` — both directions | v4-completion pass (on dev) | Forward: same machine/endpoint, empty certificate, output bit from outputEncodesChi. Backward: determinism via `evalsTo_unique_result`. |
| 10 | Certificate bound equivalence (Gate 4) | `4584d90` | Bound changed to direct `p.eval(ea(x,[])).length` (polynomial in input size). |

## Removed (not resolved)

| # | What | Commit | Notes |
|---|---|---|---|
| 2 | `P_empty_eq_upstream_P` marker theorem (Oracle.lean) | v4-completion pass (on dev) | `True`-conclusion placeholder; single sorry blocked every build. Tracking roles merged into #6/#7. |

---

## Also fixed in the v4-completion pass (not sorry items)

- **P_A / NP_A ill-typed oracle constraint.** The v4 headers claimed
  `M.oracle = A` but that equation did not typecheck — `M : Machine
  (tm'.Γ tm'.k₀) tm'` has `oracle : Oracle (tm'.Γ tm'.k₀)`, not
  `Oracle Q`. Fixed per the query-type trap: machines now quantify with
  `hΓ : tm'.Γ tm'.k₀ = Q` and the constraint is `M.oracle = hΓ.symm ▸ A`.
  (Unobservable on dev because the build never got past the substrate
  sorry.)
- **NP_A typo.** `oa : tm'.Γ tm.k₁ → Bool` referenced unbound `tm`
  (never compiled).
- **Relativization.lean arg names.** `P_A (α := …)` → `P_A (alpha := …)`
  (never compiled against the class signature).
- **Smoke test (v4 acceptance item).** `OracleSmoke.lean`: one machine
  program, two oracle instantiations — `smoke_accepts_true` (accept, by
  evaluation) and `smoke_rejects_false` (reject, by determinism +
  evaluation). The executable check that Flaw B stays fixed.
- **Determinism lemma.** `evalsTo_unique_result` + `step_none` in
  `Oracle.lean` — the lemma #5b needed and the reject-side of the smoke
  test uses.

---

## Remaining tasks

1. **#6: fill the statement-level sorry** in `P_empty_eq_upstream_P_class`
   with the upstream-P set — needs Mathlib's P (DEC-003) or an
   oracle-free recharacterization (machine-transformation formalization).
   **Gate-5 concern, first in line when unblocked.**
2. **#7: prove the equality** — pending #6.
3. **#8, #9: BGS proofs** — blocked on PSPACE/QBF + machine enumeration +
   upstream P (Rung 3 Step 6).

The BGS statement (`∃ A, Computable A ∧ P^A = NP^A` / `∃ B, Computable B ∧ P^B ≠ NP^B`) is a barrier theorem *statement* rendered over machine-grounded, non-vacuous oracle classes (P^A/NP^A built on a real TM model with `EvalsToInTime` step counting). Prior renderings exist only as axioms over vacuous classes or as abstract schemes (see `docs/PRIOR_ART.md`, "Closer prior art"); ours is intended to be *provable*, not assumed. It type-checks and satisfies the rendering spec's three traps (computability hypothesis, set equality, query type). We do not claim priority — the point is that the statement is provable-in-principle, which the axiom/scheme renderings are not.

---

## Dependency chain


```
#6 (statement) → #7 (proof)            [upstream P, DEC-003]
#8/#9 (BGS)    ← needs {PSPACE/QBF, machine enumeration}  + upstream P
```

