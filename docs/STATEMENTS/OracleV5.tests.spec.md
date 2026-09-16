# Test spec: v5 word-query oracle substrate (issue #40)

**Status:** Executable coverage landed 2026-09-13 (modules
`lean/PleaNP/Computability/OracleV5Tests.lean` — the CI-built `PleaNP.*`
library module — and `lean/tests/OracleV5.lean` — the `tests`-lib suite
wired into the `test` exe; follow-up to #33/#35, the v5 word-query
substrate repair).

**Purpose.** A regression contract for the v5 accept-only items the repair
must not lose. The executable checks live in the two modules above; this
document is the coverage narrative / spec the tests implement. Since
Lean's `example`s and theorems *must* typecheck, any substrate regression
that violates these contracts fails the build.

Reference: `docs/STATEMENTS/Oracle.v5-repair.spec.md` §4.3 (invariants) and
§5 (acceptance criteria).

---

## 1. Query is exactly one step (§4.3(2) / §5(4))

**Contract.** The query transition — consulting the oracle on the decode of
the query word — is *exactly one* `step` application of the real machine
step function (no simulation, no amortization, no 0-cost query), and it
routes to `yesLabel` iff the oracle answers `true`, `noLabel` iff `false`.

**Executable check.** Two `rfl` examples on the real `step`:

```
example : (step (v5M v5OracleTrue) (initCfg (v5M v5OracleTrue) v5QueryWord))
              .map (.cfg.l) = some (some V5Label.yes) := by rfl
example : (step (v5M v5OracleFalse) (initCfg (v5M v5OracleFalse) v5QueryWord))
              .map (.cfg.l) = some (some V5Label.no) := by rfl
```

Both are definitional: the consultation is exactly one `step`, and the
answer selects the branch label.

## 2. Word-query smoke machine (§5(3))

**Contract.** A concrete machine whose query *word* is nontrivial
(`v5QueryWord := [true, false, true]` — the "101" analogue over the Bool
alphabet) reads that word via `decode`, queries once, and the oracle answer
is observable end-to-end: accept under the always-true oracle, reject under
the always-false oracle.

**Executable check.** `v5_smoke_accepts_true` (accept within 2 steps,
closed by evaluation) and `v5_smoke_rejects_false` (no halted reachable
config outputs `true`; closed by determinism `evalsTo_unique_result` +
evaluation). This is the §5(3) "word-query analog" of the pre-v5
`OracleSmoke`.

## 3. P^∅ = P empty-oracle note (§4.2(4) / §5(5))

**Contract.** With the empty oracle (`emptyOracle O := fun _ => false`) the
query channel is inert: every query answers `false`, and instantiating a
machine with `emptyOracle` is the same as with an always-false oracle — so
the class statements reduce to the no-oracle reading that
`OracleUpstreamP.lean`'s P^∅ = P anchor builds on.

**Executable check.**

```
example (q : V5Query) : emptyOracle V5Query q = false := rfl
example : v5M v5OracleFalse = v5M (emptyOracle V5Query) := rfl
```

The first pins the empty oracle's answer; the second notes the machine
witness equality that makes the P^∅ → P statement read off a stable base.

---

## Coverage mapping

| v5 spec item | Test | Module decl |
|---|---|---|
| §4.3(2) / §5(4) query = 1 step | yes/no one-step `rfl` examples | `step`-on-`initCfg` examples |
| §5(3) word-query smoke | accept / reject theorems | `v5_smoke_accepts_true`, `v5_smoke_rejects_false` |
| §4.2(4) / §5(5) P^∅ = P | empty-oracle facts | `emptyOracle` examples |

**Regression contract.** If any of the above stops compiling (or the
theorem proofs stop closing), the v5 substrate §5 acceptance items have
regressed and the module's build fails — the intended "build is the test
harness" pattern (same as `OracleSmoke.lean` / `BarrierCalculusFuneq.lean`).


---

## 4. P^∅ = P statement fully rendered (Trap 3 regression-contract bonus)

The v5-repair acceptance §4.2(4)/§5(5) wants the P^∅ = P anchor at
the *statement* level. This was sharpened in the same pass (issue #40,
run=20260913-1007-fUj8): the RHS of the anchor's theorem is no longer a
statement-level `sorry` hiding as `{ L | sorry }`.
`OracleComplexity.lean` gained `UpstreamPolyTime` — the oracle-free
`TM2ComputableInPolyTime` recharacterization (characteristic function
`χ : alpha → Bool` computed in polytime, `χ x = true ↔ x ∈ L`; the
function→language bridge, Trap 1) — and `OracleUpstreamP.lean` now renders:

```lean
theorem P_empty_eq_upstream_P_class {Q : Type} (alpha : Type) :
    P_A (alpha := alpha) (emptyOracle Q) = UpstreamPolyTime alpha := by sorry
```

resolving **SORRY_TRACKER #6** (statement-level sorry filled); the honest
proof `sorry` (#7) still tracks upstream P (DEC-003 / #4). `tests.OracleV5`
sanity-checks `UpstreamPolyTime` is non-vacuous (a concrete Bool language is
a member, witnessed by Mathlib `idComputableInPolyTime`).

## Build & run

```bash
cd lean
lake build PleaNP.Computability.Oracle PleaNP.Computability.OracleComplexity PleaNP.Computability.OracleSmoke PleaNP.Calculus.BarrierCalculus
lake build tests        # the tests lib: tests.OracleV5 + tests.BarrierCalculusFuneq
lake build test         # links the runnable test exe (root tests.Basic)
./.lake/build/bin/test  # exit 0
```

## Gate evidence expected at done

- `lake build tests` / `lake build test` green (both the `PleaNP.*`
  `OracleV5Tests` module and the `tests.*` `OracleV5` suite).
- hygiene/vacuity/model/binder scans clean on the touched modules (the
  `by decide` review items in `OracleSmoke.lean` are pre-existing and
  documented in `docs/GATE_REVIEW_NOTES.md`).
- `OracleUpstreamP.lean` reports **one** `sorry` (the honest proof #7),
  down from two — SORRY_TRACKER #6 marked Resolved in the same commit.
