# Sorry tracker: open proof/composition debts

**Purpose.** Track every `sorry` in the PleaNP Lean codebase — what it's pending on, what unblocks it, and its priority. This prevents `sorry`s from being forgotten or filled in wrong (the exact failure mode `FAILURE_AUDIT.md` Pattern A warns about: a `sorry` that's silently resolved against the wrong condition, or never resolved, making a "compiling proof of the wrong statement" look authoritative).

**Rule:** every `sorry` in `lean/PleaNP/` must appear in this table. When a `sorry` is resolved, update the table (mark it "Resolved" with the commit that resolved it). When a new `sorry` is added, add it here. The hygiene scanner (`tooling/gates/hygiene_scan.py --prove-stage`) enforces that no `sorry` ships in a *proven* claim — this doc tracks what each one means.

**Last updated:** 2026-08-18 (this commit).

---

## Summary

| File | `sorry` count | Level |
|---|---|---|
| `lean/PleaNP/Computability/Oracle.lean` | 2 | Substrate (Rung 2) |
| `lean/PleaNP/Computability/OracleComplexity.lean` | 5 | Complexity classes (Rung 2) |
| `lean/PleaNP/Barriers/Relativization.lean` | 2 | Barrier statement (Rung 3a) |
| **Total** | **9** | |

All 9 are honest pending proofs/compositions (Gate 6 catches them; none are dishonest placeholders — Gate 5 passes clean). None are "fake successes" (`True`/`trivial`/`none` bodies); all express real conditions that await completion.

---

## Detailed inventory

### Substrate level (`Oracle.lean`)

| # | File:Line | What it's pending on | Unblocked by | Priority |
|---|---|---|---|---|
| 1 | `Oracle.lean:~210` | ~~`outputEncodesChi`~~ **Resolved** (commit 5243a06) | — the per-machine output-encoding bridge (Bool → FinTM2 output alphabet). The predicate that checks the halted config's output encodes `χ_L(x)`. | Per-machine instantiation (likely in `OracleComplexity.lean` or a `Relativization.lean` instance). The dependent-type issue: `tm.Γ tm.k₁` (output alphabet) varies per machine. | **High** — this is the acceptance condition `DecidesInTime` depends on; without it, `P^A`/`NP^A` membership is undefined. |
| 2 | `Oracle.lean:~259` | `P_empty_eq_upstream_P` — the `P^∅ = P` compatibility statement (Trap 3 of the recompose spec). Proves the empty-oracle case reduces to non-oracle `TM2ComputableInPolyTime`. | Upstream `P` (not in Mathlib core, DEC-003) + the `outputEncodesChi` bridge (#1). | **Medium** — the statement is rendered; the proof tracks upstream P. |

### Complexity-class level (`OracleComplexity.lean`)

| # | File:Line | What it's pending on | Unblocked by | Priority |
|---|---|---|---|---|
| 3 | `OracleComplexity.lean:~56` | ~~`P_A` membership condition~~ **Resolved** (commit pending) — now composes @DecidesInTime with ea, oa, M, L, p. | — `∃ ..., sorry` instead of `DecidesInTime ea M L p`. The composition with `DecidesInTime` (which itself depends on #1, `outputEncodesChi`). | `outputEncodesChi` (#1) + per-machine input encoding (`ea : α → List (tm.Γ tm.k₀)`). | **High** — without this, `P^A` is a set with a pending membership condition; the BGS statement quantifies over it but can't be meaningfully interpreted yet. |
| 4 | `OracleComplexity.lean:~94` | ~~`NP_A` verifier condition~~ **Resolved** (commit pending) — now composes @DecidesInTime on (x, y) pair with verifier language { (x,y) | x in L }. | — `∧ sorry` instead of `DecidesInTime` on a two-input encoding `(x, y)`. Same composition dependency as #3. | `outputEncodesChi` (#1) + two-input encoding. | **High** — same as #3 for `NP^A`. |
| 5 | `OracleComplexity.lean:~105` | `P_A_subset_NP_A` — the trivial inclusion proof (`P^A ⊆ NP^A`). Should be provable from the definitions (structural self-check). | #3 and #4 being resolved (the proof needs the real class bodies). | **Medium** — a self-check; if it can't be proven after #3/#4 are resolved, the class definitions are wrong relative to each other. |
| 6 | `OracleComplexity.lean:~132` | `P_empty_eq_upstream_P_class` — right-hand side set comprehension. The definition of "upstream P as a set" (`{ L | ∃ (tm' : FinTM2), sorry }`). | Upstream `P` (DEC-003). | **Medium** — carries #2 to the class level. |
| 7 | `OracleComplexity.lean:~133` | `P_empty_eq_upstream_P_class` — the proof of `P^∅ = P` equality. | #6 + upstream `P`. | **Medium** — tracks upstream P. |

### Barrier-statement level (`Relativization.lean`)

| # | File:Line | What it's pending on | Unblocked by | Priority |
|---|---|---|---|---|
| 8 | `Relativization.lean:~79` | BGS clause (a) proof — `∃ A, Computable A ∧ P^A = NP^A`. The equalizing-oracle existence proof (sandwich: A = QBF, `P^A = NP^A = PSPACE`). | #3, #4 (class bodies) + PSPACE/QBF formalization (not in Mathlib, GAP_AUDIT §8) + upstream `P` (DEC-003). | **Low (for now)** — Rung 3 Step 6; the statement is frozen (Gate 1), the proof is the multi-year core contribution. |
| 9 | `Relativization.lean:~100` | BGS clause (b) proof — `∃ B, Computable B ∧ P^B ≠ NP^B`. The separating-oracle existence proof (diagonalization: `U_B` construction, `2^n > p_i(n)` counting). | #3, #4 (class bodies) + enumeration of poly-time oracle machines + the diagonalization construction. | **Low (for now)** — Rung 3 Step 6; the hardest proof in the project (per `Relativization.proof-strategy.md`, ~70% of the effort). |

---

## Dependency chain (what unblocks what)

```
#1 outputEncodesChi (per-machine output bridge)
  ├── #3 P_A membership condition (needs #1 + input encoding)
  │     ├── #5 P_A ⊆ NP_A proof (needs #3 + #4)
  │     └── #8 BGS clause (a) proof (needs #3 + #4 + PSPACE + upstream P)
  ├── #4 NP_A verifier condition (needs #1 + two-input encoding)
  │     ├── #5 P_A ⊆ NP_A proof (needs #3 + #4)
  │     ├── #8 BGS clause (a) proof
  │     └── #9 BGS clause (b) proof (needs #3 + #4 + machine enumeration + diagonalization)
  ├── #2 P_empty = P (Oracle.lean, needs #1 + upstream P)
  │     └── #6, #7 P_empty = P (class level, carries #2 through)
  └── (upstream P/NP, DEC-003, needed by #2, #6, #7, #8)
```

**The critical path:** #1 (`outputEncodesChi`) is the root dependency — it unblocks #3 and #4 (the class bodies), which unblock #5 (the self-check), #8 and #9 (the BGS proofs). Upstream `P`/`NP` (DEC-003) is the other root — it unblocks #2, #6, #7, and #8.

**The first thing to resolve:** #1 (`outputEncodesChi`) — it's the per-machine output-encoding bridge, it's in PleaNP's control (not blocked on upstream), and it's the root of the critical path. Resolving it makes #3 and #4 writable, which makes the class bodies real, which makes the BGS statement *meaningful* (not just type-checking against pending classes).

---

## Status of the BGS statement

**Rendered (type-checks) — proof pending, class bodies pending.**

The BGS statement (`∃ A, Computable A ∧ P^A = NP^A` / `∃ B, Computable B ∧ P^B ≠ NP^B`) is the first barrier theorem *statement* rendered in any proof assistant (per `docs/PRIOR_ART.md` cross-assistant survey — no proof assistant has this). It type-checks and satisfies the rendering spec's three traps (computability hypothesis, set equality, query type).

**Qualification:** the statement quantifies over `P^A`/`NP^A` whose membership conditions are `sorry`'d (#3, #4). So the statement is *formally well-typed* but its *semantic content* is pending — it will be fully meaningful once #1 (the `outputEncodesChi` bridge) is resolved, making #3 and #4 writable, making the class bodies real. Until then, "the BGS statement is rendered" means "the statement type-checks against pending class definitions" — a valid Gate-1 frozen anchor, not a completed theorem.

**Do not claim "BGS proven" or "barrier formalized" until #8 and #9 are resolved** (the proofs) AND #3/#4 are resolved (the class bodies). A green `lake build` with `sorry` in the proofs is a *rendered statement*, not a *theorem*.
