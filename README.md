# PleaNP

A Lean 4 / Mathlib project formalizing the **barrier landscape** of computational complexity theory — the meta-theorems showing which classes of proof techniques *provably cannot* resolve the P vs NP problem — together with the surrounding circuit complexity and proof-complexity infrastructure those barriers require.

> "Plea" — because this is the road we're building toward P vs NP, not the claim we've reached it.

## Why this project exists

The P vs NP problem has three decades of known **barriers**:

| Barrier | Year | Core message |
|---|---|---|
| Relativization | Baker–Gill–Solovay, 1975 | Any relativizing proof cannot separate P from NP (oracles exist on both sides). |
| Natural proofs | Razborov–Rudich, 1994 | Natural lower-bound techniques would break pseudorandom functions / one-way functions. |
| Algebrization | Aaronson–Wigderson, 2008 | A third barrier refining the first two, covering modern lower-bound techniques. |

These barriers are the map of where P vs NP proof attempts fail. Encoding them formally turns "don't try these techniques" from folklore into machine-checkable facts — which is the prerequisite for any honest, AI-assisted proof search over the formalized landscape.

**None of these barriers has a machine-checked proof in any proof assistant, in any computational model.** (They've been stated as axioms and sketched as abstract schemes — see `docs/PRIOR_ART.md` — but never proved over real machine-grounded classes.) This project fills that gap by building the missing infrastructure: machine-grounded oracle classes and the barrier theorems on top, so the statements are *provable*, not assumed.

## Scope and non-scope

### In scope

- A formalized **barrier library**: relativization, natural proofs, algebrization.
- A **barrier calculus** (Rung 5, the crown jewel): a `Relativizing` typeclass that propagates through the dependency graph of any lemma built from relativizing pieces,plus a `#barrier_check` elaborator that walks a theorem's dependency closure and reports **"DEAD: this proof relativizes"** or **"Inconclusive."** — turning "does this proof relativize?" from per-paper human judgment into a typechecking question. Unit-tested against the time hierarchy theorem(which relativizes).
- An **anchor object** (Rung 6):machine-checked P/NP model-equivalence across whichever upstream formalizations land,plus Levin universal searchas an explicit `#eval`-able term behind `P_eq_NP_iff`.The search⟶decision gap(needs self-reducibility + a Hutter-style wrapper)is logged as a scoped open lemma,not a blocker(see DEC-012).
- A **lower-bound compiler** (Rung 8):Williams' transfer theorem(nontrivial CircuitSAT algorithm for class C ⟹ NEXP ⊄ C)as a Lean elaborator— feed it a verified algorithm + runtime bound,it emits a verified circuit lower bound. Under `PleaNP.Circuits`.
- Supporting **circuit complexity** (AC⁰,, TC⁰,, NC,, switching lemma,, monotone lower bounds)and **proof complexity** (resolution,, Frege) needed to state and apply the barriers.
- An **integrity pipeline** (the "gates")that separates statement formalization from proof search,to structurally prevent the most common failure mode of claimed P vs NP formalizations.

### Out of scope (deliberately)

- Defining P, NP, and polynomial-time reductions from scratch. These are being actively upstreamed to Mathlib by multiple efforts (see `docs/UPSTREAM_TRACKING.md`). PleaNP imports and builds on whichever lands, rather than contesting the computational-model design.
- Claiming to resolve P vs NP. The realistic outcome is a world-class formalized barrier library plus honest tooling — a serious contribution regardless of whether the top rung is ever reached.

## Project structure

```
PleaNP/
├── lean/                # Self-contained Lean 4 / lake project (the library)
│   ├── PleaNP/
│   │   ├── Barriers/    # Relativization, NaturalProofs, Algebrization
│   │   ├── Circuits/    # AC0, TC0, NC, switching lemma, monotone bounds
│   │   ├── Calculus/    # Rung 5: Relativizing typeclass + #barrier_check
│   │   └── ProofComplexity/
│   └── tests/
├── tooling/             # AI + integrity layer (Python)
│   ├── retrieval/       # Premise selection (representation experiments)
│   ├── gates/           # The integrity pipeline
│   └── audit/           # Gap-audit tooling
└── docs/                # The spec, roadmap, audit, and decision log
```

The `lean/` tree is a clean lake project with no Python dependencies — it can be extracted and contributed upstream independently.

## Current status

**Rung 1 — Gap audit.** See `docs/GAP_AUDIT.md` for the domain-by-domain analysis of Mathlib's current complexity coverage versus what the barrier theorems require.



**Rung 5 — Barrier Calculus (in progress).** The `Relativizing` typeclass + `#barrier_check` elaborator prototype lives in `lean/PleaNP/Calculus/BarrierCalculus.lean`,with the time-hierarchy-theorem unit test. It is meta-level — it does not wait on upstream P/NP. The remaining new rungs(6 Anchor Object, 8 Lower-Bound Compiler)are specced in `docs/ROADMAP.md` (DEC-012.

See `docs/ROADMAP.md` for the full rung ladder.

**Community status (2026-09-06, DEC-015):** contributions are welcome via
GitHub issues/PRs (`docs/CONTRIBUTIONS.md`); the multi-agent issue workflow is
`docs/MULTI_AGENT_WORKFLOW.md`. The project is maintained by one human + AI
agents with machine-verified integrity gates. Participation in external chat
channels (e.g. Zulip) is deliberately deferred until the artifact is
stranger-pickupable and a human accountability anchor exists — the repo is
fully GitHub-native in the meantime.

## For newcomers

Want the plain-words version — no math background needed?
Read [`docs/EXPLAINER_P_VS_NP.md`](docs/EXPLAINER_P_VS_NP.md),
a beginner-friendly telling of P vs NP and how PleaNP approaches it.

## Conventions

This project follows Mathlib's naming and style conventions for all Lean code, with project-specific declarations under the `PleaNP` namespace. See `AGENTS.md` for the condensed project reference.

## Acknowledgments

This project takes inspiration from the **Maith** project (a Lean 4 IR extraction experiment) in its documentation discipline (decision log, audit resolution markers, AGENTS.md memory) — but PleaNP is an independent formalization project, not a representation-research project.
