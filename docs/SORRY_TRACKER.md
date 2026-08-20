# Sorry tracker: open proof/composition debts

**Purpose.** Track every `sorry` in the PleaNP Lean codebase.

**Rule:** every `sorry` in `lean/PleaNP/` must appear in this table.

**Last updated:** 2026-08-19 (commit pending on dev).

---

## Summary

| File | `sorry` count | Level |
|---|---|---|
| `lean/PleaNP/Computability/Oracle.lean` | 1 | Substrate (Rung 2) |
| `lean/PleaNP/Computability/OracleComplexity.lean` | 3 | Complexity classes (Rung 2) |
| `lean/PleaNP/Barriers/Relativization.lean` | 2 | Barrier statement (Rung 3a) |
| **Total** | **6** (5a resolved) | |

All are honest pending proofs/compositions. v4 repair wired EvalsToInTime reachability (Flaw A fixed), per-input AcceptsInTime on (x,y) (Flaw C fixed), M.oracle=A constraint (oracle-relative), and removed the duplicate binder. The remaining sorries are: upstream-P-blocked (#2, #6, #7), the P_A subset NP_A self-check (#5), and the BGS proofs (#8, #9).

---

## Detailed inventory

### Substrate level (Oracle.lean)

| # | File:Line | What it is | Pending on | Priority |
|---|---|---|---|---|
| 2 | `Oracle.lean:115` | `P_empty_eq_upstream_P` -- P^empty = P compatibility. Statement only; proof tracks upstream P. | Upstream P (DEC-003). | Medium |

### Complexity-class level (OracleComplexity.lean)

| # | File:Line | What it is | Pending on | Priority |
|---|---|---|---|---|
| 5a | ~~`OracleComplexity.lean`~~ **Resolved** -- forward direction proven (by_cases on output stack, hEncodes.mpr hx) -- output-encoding connection. From DecidesInTime (outputEncodesChi gives oa head = true iff x in L) to AcceptsInTime (oa head = true). Requires unfolding the match on the output stack. | Unfolding outputEncodesChi through the match. | **High** -- structural self-check. |
| 5b | `OracleComplexity.lean:94` | `P_A_subset_NP_A` backward direction -- extracting x in L from AcceptsInTime. | Same unfolding + connecting the two reachability proofs. | **High** -- structural self-check. |
| 6 | `OracleComplexity.lean:90` | `P_empty_eq_upstream_P_class` -- RHS set comprehension (upstream P as a set). | Upstream P (DEC-003). | Medium |
| 7 | `OracleComplexity.lean:91` | `P_empty_eq_upstream_P_class` -- proof of P^empty = P equality. | #6 + upstream P. | Medium |

### Barrier-statement level (Relativization.lean)

| # | File:Line | What it is | Pending on | Priority |
|---|---|---|---|---|
| 8 | `Relativization.lean:80` | BGS clause (a) proof -- equalizing oracle existence. | #5 (class self-check) + PSPACE/QBF + upstream P. | Low (Rung 3 Step 6) |
| 9 | `Relativization.lean:101` | BGS clause (b) proof -- separating oracle existence (diagonalization). | #5 + machine enumeration + diagonalization. | Low (Rung 3 Step 6) |

---

## Resolved

| # | What | Commit | Notes |
|---|---|---|---|
| 1 | `outputEncodesChi` -- the per-machine output-encoding bridge | `5243a06` | Now a real predicate: `oa head = true iff x in L`. |
| 3 | `P_A` membership condition | `bc344ab` then v4 `a223b12` | Now composes `@DecidesInTime` with EvalsToInTime reachability. ea/M/t load-bearing. |
| 4 | `NP_A` verifier condition | `bc344ab` then v4 `a223b12` | Now composes `@AcceptsInTime` on pair (x, y) with reachability. ea/M/xy/t load-bearing. |
| 10 | Certificate bound equivalence (Gate 4) | `4584d90` | Bound changed to direct `p.eval(ea(x,[])).length` (polynomial in input size). |

---

## Remaining tasks for v4 completion

1. **#5a/#5b: Prove P_A_subset_NP_A** (not sorry). The proof structure is:
   - Forward: given L in P_A (decider M with DecidesInTime), construct NP_A verifier (same M, pair-encoding ea'(x,y)=ea(x), empty certificate y=[]). AcceptsInTime follows from DecidesInTime (same initial config, same reachability, output is true because x in L implies oa head = true).
   - Backward: given y and AcceptsInTime (output is true), extract x in L from the P_A decider's outputEncodesChi (oa head = true iff x in L).
   - Obstacle: unfolding outputEncodesChi through the match on the output stack.

The BGS statement (`∃ A, Computable A ∧ P^A = NP^A` / `∃ B, Computable B ∧ P^B ≠ NP^B`) is a barrier theorem *statement* rendered over machine-grounded, non-vacuous oracle classes (P^A/NP^A built on a real TM model with `EvalsToInTime` step counting). Prior renderings exist only as axioms over vacuous classes or as abstract schemes (see `docs/PRIOR_ART.md`, "Closer prior art"); ours is intended to be *provable*, not assumed. It type-checks and satisfies the rendering spec's three traps (computability hypothesis, set equality, query type). We do not claim priority — the point is that the statement is provable-in-principle, which the axiom/scheme renderings are not.


2. **Smoke test**: one concrete FinTM2 machine, two oracles A1 != A2, one input x, with AcceptsInTime ... A1 ... x and not AcceptsInTime ... A2 ... x both closed by decide. Requires constructing a concrete FinTM2 (Fintype instances etc.).

3. **Module headers**: update v3 headers to v4 (claim "reachability wired" only where the body actually uses EvalsToInTime).

4. **#2, #6, #7: P_empty = P** -- blocked on upstream P (DEC-003). Not in PleaNP's control.

5. **#8, #9: BGS proofs** -- blocked on #5 + PSPACE/QBF + upstream P. Rung 3 Step 6.

---

## Dependency chain



