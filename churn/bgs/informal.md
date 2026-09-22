# bgs

Informal claim:

> Baker-Gill-Solovay: there exist oracles that separate and equalize P^A vs NP^A

## Frozen statement (word-query substrate, v5)

The campaign renders exactly one statement, unchanged across all slots:

```
U_B ∈ NP_A (alpha := Nat) B        over   Query = Σ n : Nat, Bits n
```

- `U_B`, `Bits`, `Query`, `IsWitness` — `lean/PleaNP/Barriers/BGSDiagonal.lean`
  (sub-task #21).
- The concrete guess-query-verify machine — `lean/PleaNP/Barriers/DiagonalUB.lean`
  (`ubTM`, `ubM`, `encWord`/`decodeWord`, sub-task #36).
- `NP_A` / `AcceptsInTime` — `lean/PleaNP/Computability/OracleComplexity.lean`.

The v5 repair (issue #35, DEC-024) removed the `Fintype Query` wall: the oracle
machine's tape alphabet stays finite (`List (tm.Γ tm.k₀)`, `FinTM2`'s bundled
`Fintype`), while the *query value-space* `Q = Σ n, Bits n` is arbitrary (here,
infinite). The machine's `decode : List (tm.Γ tm.k₀) → Q` maps the queried word
to the value-space. Earlier slot framings that worked around a bundled
`Fintype (Γ k₀) = Query` constraint are obsolete under v5 — see the per-slot
re-scope below.

## Slot lenses (re-scoped to the word-query substrate, issue #38)

The four lenses direct a renderer to a different corner of the *same* frozen
statement's shape space. Isolation is unchanged: each renderer sees only this
seed (`informal.md`), its own `churn/bgs/renderings/<id>.{lean,json}`, the
licensed imports, and repo conventions — never another slot's rendering.

- **Slot A — structure-first.** Quantifier skeleton front-and-center:
  `∃tm', ∃hΓ, ∃ea, ∃oa, ∃M, ∃p, ∀x` — with minimal proof content. Under v5,
  `hΓ` is *not* `tm'.Γ tm'.k₀ = Query` (the fused v4 form that hit the wall);
  it is the machine's own `decode : List (tm'.Γ tm'.k₀) → Query` slot. Render
  the statement's quantifier order and types first, leaving the machine body
  opaque.
- **Slot B — machine construction.** The concrete word-writing
  guess-query-verify machine — the #36 shape (`ubTM`/`ubM` in `DiagonalUB.lean`):
  decode the input word into `Query`, consult the oracle once (1 step, per v5),
  accept/reject on the answer. Render the explicit `FinTM2` program plus the
  step/accept-run sketch; the language/class shape stays exactly
  `U_B ∈ NP_A (alpha := Nat) B`.
- **Slot C — witness-predicate.** The `∃y` bound + the `AcceptsInTime (x, y)`
  conjuncts, with the witness predicate `IsWitness` (`B ⟨n, x⟩ = true`)
  front-and-center. Under v5 the certificate `y` is the *list of queried word
  content*, not a reindexed query family — render the witness bundling and the
  acceptance conjuncts directly over `Query`.
- **Slot D — query-tape-encoding-focused.** How the input length `n` ties to the
  queried word's decoding: the `encWord n x` / `decodeWord` round-trip
  (`decodeWord_encWord`) that carries `Bits n` through the finite tape word into
  `Query = Σ n, Bits n`. Render the encoding bridge (the `n ↦ ⟨n, ·⟩` tagging)
  as the load-bearing content, testing whether a length-parametric framing can
  host the claim without a per-length family.

These are *lenses*, not substrate edits: no slot may change the frozen statement
above. Byte-identical claims rendered through four different lenses is the point
— structural divergence in the rendering, not the target.

## Isolation & diversity (unchanged)

All four slots use the same LLM; lenses, not temperature, force structural
divergence (see `docs/MULTI_AGENT_WORKFLOW.md` §Rendering-campaign protocol,
"Slot-diversity discipline"). Each slot submits its own `<slot>_notes.md`
recording which lens choices it made. The `merge` step's pairwise matrix is the
enforcement point: the `#25` `check` is pairwise machine-checked equivalence
(with `lemmas.json` IFF bridging where ambiguity is proved), and disagreements
become `review_inbox` points.

## Campaign flip condition (issue #38 DoD)

This re-scope is design work only. The campaign flips from
`status:blocked-needs-input` (on #27) to `status:available` — making the slots
claimable under `#24`'s campaign protocol — once the human confirms the lens
mechanism:

- reply `confirm` on #27, **or**
- comment on #38 confirming the four re-scoped lenses above.

If all slots come back EQUIVALENT (no disagreements), that is itself the measured
result: the human still reviews exactly one confirm probe on the agreed shape +
a perturb-control twin (`review_inbox.py perturb`, per the fatigue protocol —
the control should be flagged, proving the review is not rubber-stamp). There is
no "nothing to review" state.
