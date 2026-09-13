# `#barrier_check` soundness — oracle-uniformity semantics (issue #65)

**Status:** Implemented (run=20260913-1012-uJoS), module
`lean/PleaNP/Calculus/Soundness.lean`. Abstract form (over `Oracles.Oracle`);
the concrete `NP_A`/class-equality hook is a documented plan (§4), not
`sorry`'d.

**Closes:** `docs/GRANT_READINESS.md` hole #4 ("`#barrier_check` soundness is
unproven") for the abstract/marker-grammar half; the complete concrete
class-equality BGS hook tracks #18/#63/#82 (the equalizing/separating oracle
constructions).

## 1. The soundness claim

`#barrier_check` emits **DEAD** when instance search finds both a
`Relativizing` marker and a `PVsNPShaped` marker on a claim's body. That
verdict is authoritative only if `Relativizing` *means* "this construction is
uniform in the oracle" (BGS). Since `Relativizing` is a field-less marker, its
meaning cannot be introspected — so this module gives it a semantic model and
proves the marker system is sound for it.

## 2. The semantic model

`UniformInOracle O P` for `P : Oracle O → Prop`: the family's truth is
invariant under replacing the oracle with any other oracle that answers every
query identically (extensional equality of the answer function). This is the
precise "never inspects the oracle beyond the answer stream" property.

## 3. Proved lemmas (zero sorries)

| Lemma | Meaning |
|---|---|
| `relAtom_uniform` | the `Relativizing.relAtom` seed is uniform |
| `langAtom_uniform` | the `Relativizing.langAtom` seed is uniform |
| `pA_mem_uniform` | the **concrete** `L ∈ P_A A` membership atom is uniform (the post-#35 hook) |
| `uniform_and/or/imp/iff/not/forall/exists` | each `Relativizing.*` propagation case preserves uniformity |
| `funeq_uniform` / `funne_uniform` | the oracle-oblivious function-equality atoms are uniform |
| `transfer_under_ext` | a uniform family's truth transfers between ext-equal oracles |
| `sound_verdict_abstract` (+ `_rev`) | a `Relativizing` `LangAtom` claim transfers its verdict across ext-equal oracles |

Together: *every statement built from the seeded atoms through the
propagation grammar is uniform in the oracle* — the marker system is sound for
everything it classifies.

## 4. Concrete `NP_A`/class-equality hook — documented plan (NOT proved here)

`L ∈ NP_A A` is uniform by the same construction as `pA_mem_uniform`: under
extensionally-equal oracles the verifier's queries answer identically, so
`AcceptsInTime` transfers (the `NP_A` membership atom). The class equality
`P_A A = NP_A A` then transfers by `pA_mem_uniform`/`npA_mem_uniform` applied
elementwise (via `Set.ext`), which is the `sound_verdict`-shaped transfer the
full BGS DEAD consequence needs. Those proofs (and the equalizing/separating
oracle constructions `E`/`S` that turn the uniformity into a `False`
contradiction) are the subjects of #18/#63 and the Rung-5 follow-ups; they are
**not** silently `sorry`'d here.

## 5. Gate evidence

- `lake build PleaNP.Calculus.Soundness` green (Lean v4.31.0 / Mathlib v4.31.0); module added to the CI clean-set build.
- hygiene `--prove-stage`: 0 violations (no sorries).
- vacuity / model-consistency / unicode: clean.
- binder scan: 0 violations; 13 REVIEW items (the library-level uniformity
  lemmas, an intentional public API for downstream Rung-5 proofs — same
  demonstrated-intentional pattern as the `BarrierCalculus` propagation
  instances in `docs/GATE_REVIEW_NOTES.md`).
- axiom check: only standard axioms; no `sorryAx`.
- existing `#barrier_check` unit tests (4 abstract verdicts) still pass;
  the `ConcreteSeed` 2 concrete verdicts (from #82) still pass (harness = 6).

## 6. Follow-up (Tests)

A `Tests:` follow-up asserting the soundness lemmas' axioms in CI and
exercising the class-transfer theorem once #18/#63 land — filed per protocol.