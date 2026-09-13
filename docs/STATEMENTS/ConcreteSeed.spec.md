# Concrete Relativizing seeds on `P_A`/`NP_A` — Rung 5 integration (issue #82 Pass 1)

**Status:** Implemented (run=20260913-1008-atAo), module
`lean/PleaNP/Calculus/ConcreteSeed.lean`.
**Prerequisite:** #35 (v5 word-query oracle substrate) — the concrete
`Oracles.Oracle`/`P_A`/`NP_A` the seeds attach to.

## Purpose

Connect the abstract Barrier Calculus (Rung 5) to the concrete oracle-relative
class definitions. The abstract `AbstOracle` and concrete `Oracles.Oracle` are
definitionally the same type (`Q → Bool`); the calculus' `Relativizing` marker
is seeded on the **concrete class-membership atoms**, so `#barrier_check` can
run on actual BGS-shaped statements over `P_A`/`NP_A`, not just the abstract
unit-test statements.

## What got a seed (and why)

- `Relativizing (L ∈ P_A A)` — `Relativizing.pA_mem`.
- `Relativizing (L ∈ NP_A A)` — `Relativizing.npA_mem`.

Both are the concrete counterparts of the abstract `Relativizing.langAtom`:
a membership statement "L is decidable / has a polytime verifier relative to
A" is **uniform in the oracle** — the machine's queries are exactly-one-step
oracle answers (`OracleTM2Recompose.spec.md` §4 trap 2), and step counting
never inspects A's content. Seeding the *membership atom* (not a whole proof)
is the honest form of the AGENTS.md discipline: instance search still walks
the dependence graph of any larger statement via the propagation instances.

## What did NOT get a seed (the interesting non-relativizing case)

- The **class-level equality** `P_A A = NP_A A` and the **BGS meta-statement**
  `∃ A, P_A A = NP_A A` (`bgsMetaStatement`) are deliberately left
  instance-free. That is the BGS point: a proof constructing an equalizing
  oracle is non-relativizing — and `#barrier_check` must therefore answer
  **Inconclusive** (not ruled out by BGS). This is the discipline's stated
  "new definitions that can't [relativize] are the interesting case."

## `#barrier_check` verdicts

```
#barrier_check concreteClassMembership → DEAD — this proof relativizes,
    and concludes a P-vs-NP-shaped claim; so BGS rules it out.
#barrier_check bgsMetaStatement        → Inconclusive — no Relativizing
    instance on this statement; so it is not ruled out by BGS.
```

The first is a concrete *relativizing* P-vs-NP-shaped statement (a proof of it
cannot resolve P vs NP per BGS); the second is the interesting negative — the
actual equalizing-oracle existence remains a live, non-relativizing target.

## Gate evidence (Pass 1)

- `lake build PleaNP.Calculus.ConcreteSeed` green (Lean v4.31.0 / Mathlib
  v4.31.0); existing `BarrierCalculus` verdict unit tests still pass
  (`barrier_check_test.py` harness: all 4 verdicts present).
- hygiene `--prove-stage`: 0 violations (no sorries).
- vacuity / model-consistency / binder / unicode: clean.
- axiom check (Gate 6 Tier 2): `Relativizing.pA_mem` /
  `Relativizing.npA_mem` use only standard axioms, no `sorryAx`.

Pass 2 (of #82) — run `#barrier_check` on a real P-vs-NP-shaped statement
over the concrete classes with the expected verdict (DEAD for a relativizing
constructed claim; Inconclusive for the BGS meta-statement) — is already
covered by the two invocations above; the remaining Pass-2/CI wiring
(asserting the new verdict lines in the CI harness) is a follow-up.