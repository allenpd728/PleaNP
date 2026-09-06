# Roadmap:the rung ladder

> **Scope note (2026-09-06, DEC-012):** Three target components have been added since the original roadmap: **Barrier Calculus** (Rung 5), **Anchor Object** (Rung 6),and **Lower-Bound Compiler** (Rung 8),in that priority order. They are described in their own sections below; the former rungs are renumbered. The core bet:is *negative-space specification*: formalizing the constraints a proof must satisfy, not the proof itself,. The `#barrier_check` artifact (Rung 5) is the demand-pull device that turns "does this proof relativize?" from per-paper human judgment into a typechecking question

This is the development ladder for PleaNP. Each rung is independently valuable; the project produces a defensible research contribution at every rung, independent of whether the top rung is ever reached.

The honest framing: **the most likely outcome of this program is not "P vs NP solved." It's "a world-class formalized complexity-theory and barrier library, plus honest AI-formalization tooling, plus possibly some progress on open problems one rung below P vs NP."** That is a serious contribution on its own merits.

---

## Rung 1 — Gap audit (current)

**Goal:** A written, domain-by-domain analysis of Mathlib's current complexity coverage versus what the barrier theorems require.

**Deliverable:** `docs/GAP_AUDIT.md`.

**Output:** The spec for Rungs 2–4. Tells us whether each rung is "build from scratch" or "Mathlib is already most of the way there."

**Status:** Done. The audit also tracks the active upstream efforts adding P/NP to Mathlib (see `docs/UPSTREAM_TRACKING.md`), since Rung 2 is upstream-tracked rather than built locally. The audit is a living document — re-review when upstream lands.

---

## Rung 2 — Computational model + canonical P/NP (upstream-tracked)

**Goal:** A reusable, agreed computational model in Lean, with P, NP, polynomial-time reductions, NP-hardness, NP-completeness, and oracle machines as first-class objects.

**Stance:** This rung is *upstream's* problem, not ours. Multiple active Mathlib efforts (tracked in `docs/UPSTREAM_TRACKING.md`) are contesting the right design:
- `Turing.TM1` with fuel-based step counting (Mathlib #35366)
- `FinTM0` bundled type with relational evaluation (PR #33132)
- Machine-free logical definability via `ModelTheory` (descriptive-complexity)
- λ-calculus model L (the Coq precedent — Forster/Kunze)
- Reitwiessner's multi-tape + space-bounded model (Lean Together 2026 — the only effort targeting *space* bounds)
- complexitylib (Schlesinger) and Keßler's Mathlib fork — standalone formalizations of P/NP

PleaNP imports whichever lands upstream, rather than picking a side. Our only local requirement: **oracle machines** (a TM with an oracle tape), which none of the upstream efforts provide but relativization requires.

**Status:** Blocked on upstream. The oracle-machine layer is ours to build once a base model lands.

---

## Rung 3 — Formalize the barrier theorems (the core deliverable)

**Goal:** Machine-checked proofs of:
- **Relativization** (Baker–Gill–Solovay, 1975): there exists an oracle A with P^A = NP^A; there exists an oracle B with P^B ≠ NP^B. Therefore any relativizing proof cannot separate P from NP.
- **Natural proofs** (Razborov–Rudich, 1994): under the assumption that one-way functions exist, no natural property can prove superpolynomial circuit lower bounds.
- **Algebrization** (Aaronson–Wigderson, 2008): the third barrier, covering techniques that evade the first two.

**Why this matters:** This is the exact knowledge an AI proof-search system needs encoded to avoid dead ends. A formalized "do not try relativizing/natural/algebrizing techniques" map makes search tractable and honest. None of these has a machine-checked proof in any proof assistant today — they've been stated as axioms or abstract schemes, but never proved over machine-grounded classes (see `docs/PRIOR_ART.md`, "Closer prior art"). We build them as provable theorems.

**Scope notes (from the prior-art review):**
- **3a (relativization):** the cleanest target — an existence result about oracles, depends only on Rung 2's oracle machines. Formalize against the original Baker–Gill–Solovay 1975 statement. The frozen, human-verified informal-to-formal spec lives at `docs/STATEMENTS/Relativization.md` (Gate 1 anchor / Gate 4 read-back reference).
- **3b (natural proofs):** formalizes the *conditional* (`OWF exists ⟹ no natural property gives superpoly lower bounds`); the one-way function enters as a **hypothesis**, not a constructed object — PleaNP does *not* build a PRF, it states the conditional cleanly (no importable Lean/Coq/Isabelle crypto substrate exists; see `docs/PRIOR_ART.md`, crypto-substrate section).
- **3c (algebrization):** pin the **original Aaronson–Wigderson 2009 (multiquadratic) formulation** as the v1 target; track the ITCS 2026 multilinear-strengthening as a candidate v2, not part of v1 (prevents formalizing a moving folk theorem).

**Status:** Not started. Depends on Rung 2 (oracle machines, P/NP).

---

## Rung 4 — Formalize lower-bound techniques and their failures

**Goal:** Formalize existing lower-bound results *and* prove within Lean that they are natural/relativizing/algebrizing and therefore cannot lift to P vs NP.

**Coverage:**
- Circuit complexity: AC⁰ lower bounds (parity ∉ AC⁰ via the switching lemma), monotone circuit lower bounds (Razborov).
- Proof complexity: resolution size/width, Frege systems.
- The Williams (2011) result (NEXP ⊄ ACC⁰) — the one known non-relativizing, non-natural, non-algebrizing lower bound — as the existence proof that barrier-evading techniques exist.

**Status:** Not started. Depends on Rung 3.

---

## Rung 5 — Barrier Calculus (compositional typeclass propagation — the crown jewel

**Goal (from the scope expansion, DEC-012):** Don't just state relativization/natural-proofs/algebrization as standalone theorems. Define oracle-relative classes `P[O]`, `NP[O]` alongside concrete `P`, `NP`; create a **`Relativizing` typeclass** that propagates automatically through the dependency graph of any lemma built from relativizing pieces;and build a **`#barrier_check` macro/elaborator** that walks a theorem's dependency closure and outputs **"DEAD: this proof relativizes"** (derived from Baker–Gill–Solovay) or **"Inconclusive."**

**Why this is the crown jewel:** It converts "does this proof relativize?" from per-paper human judgment into a *typechecking question*. Every future claimed-proof triage run creates demand for it — the demand-pull artifact binding the whole integrity pipeline together. Deep integration with Rung 3's BGS clauses:(a) `P^A = NP^A` collapse oracle + (b) `P^B ≠ NP^B` separating oracle mean any proof labeled `Relativizing` that concludes `P ≠ NP` (or `P = NP`) is *self-inconsistent* —thatic contradiction is what `#barrier_check` reports as "DEAD."

**Design sketch (prototype-landing in this repo):**
- `Relativizing`as a prop-carrying typeclass(over theorem statements/definitions):an instance says "this construction is uniform in the oracle and step-counting is oracle-oblivious" (relativizes).
- Propagation instances:composition (relativizing pieces composed relativize), application, quantification, equality/inequality over oracle-relative classes,, etc. — so the typeclass diffuses through the dependency graph automatically.
.
 A constructed proof gets its instances built from its *parts*;no human annotation per-lemma beyond the seed instances`Relativizing P`, `Relativizing NP`, `Relativizing (P[O])`, etc.
- `#barrier_check` (elaborator):mark a declaration;the elaborator walks its dependency closure (recursively collecting `Relativizing` instances),and:
  - if every leaf is relativizing and the conclusion separates or collapses `P`/`NP` — emit **"DEAD: this proof relativizes"**;
  - if any leaf is non-relativizing — emit **"Inconclusive."**

**Unit-test it against the time hierarchy theorem**, which genuinely *does* relativize —that's the correctness check before trusting it on anything else. The time-hierarchy theorem (THH: `DTIME(f) ⊊ DTIME(g)` for `f = o(g)` reasonable time bounds) is relativizing (it holds relative to any oracle with the same proof), so `#barrier_check` on a THH-shaped statement must emit "DEAD"; because THH is not a P-vs-NP claim, this alsovalidates the tool outputs "Inconclusive" for the P-vs-NP-shaped claims that aren't actually barrier-laden. Holds also as a negative test: a proof of `P ≠ NP` *without* any `Relativizing` instance must emit "Inconclusive" (not DEAD), since non-relativizing proofs escape BGS.

**Placement:** `lean/PleaNP/Calculus/BarrierCalculus.lean` (new directory `PleaNP.Calculus`.. `#barrier_check` is an elaborator command, so it needs `elab` syntax — the local agent renders it; prototypes may live in `lean/PleaNP/Calculus/` and a `#barrier_check`-marked test file.

**Status:** In progress (prototype landing —thenew first concrete task of the scope expansion;see `lean/PleaNP/Calculus/BarrierCalculus.lean` and `docs/decisions/LOG.md` DEC-012.) Unit test against THH shape. NOT gated on upstream P/NP — it is meta-level (typeclass propagation over *relative* classes),so it can proceed while Rung 2's upstream substrate is still blocked.



## Rung 6 — Anchor Object (robust statement + Levin search

**Goal (from the scope expansion, DEC-012):** PlerNP continues to defer P/NP base definitions to upstream Mathlib(unchanged — don't refight that battle). But add:
- **(a) Machine-checked equivalence across upstream formalizations.** Whichever ≥2 formalizations land upstream(Turing-machine vs. uniform-circuit, etc.), prove an equivalence theorem connecting them,so the *statement* `P vs NP` is robust — independent of which model wins. These are "anchor" equivalences:they pin the meaning of P/NP across the model split.
- **(b) Formalized Levin universal search and `P_eq_NP_iff` in terms of one explicit `#eval`-able term.** Levin's universal search algorithm(`L_search`)is finite,explicit,and `#eval`-able;behind it,state `P_eq_NP_iff` as an actual *term* — not just an informal slogan.

**Explicit scope flag (DEC-012):** Extending this from the *search* version to the *decision* version needs **self-reducibility** + a **Hutter-style proof-search wrapper** — that gap is itself a real,scoped,publishable lemma,not a blocker on the roadmap. It is logged as an open item,in `docs/decisions/LOG.md` DEC-012,so it isn't glossed over nor silently treated as done.

**Status:** Blocked mostly on upstream(equivalence needs ≥2 landed formalizations;Levin-search needs a landed base model thenothing to `#eval`-against). The search⟶decision gap lemma is formulable as soon as one base model lands — it is *the* first deliverable of this rung,since it doesn't need the equivalence pair. Not started aside from the DEC entry.

 

---

## Rung 7 — Graded benchmark

**Goal:** A set of formalization tasks at increasing difficulty:
1. Textbook complexity (easy)
2. Cook–Levin (medium — already done in Coq/Isabelle, so a reference exists)
3. A recent lower-bound paper (hard)

**Purpose:** Measure AI progress honestly. Also the testbed where representation-retrieval questions (à la Maith's H6) get a concrete evaluation.

**Status:** Not started.

---

## Rung 8 — Lower-Bound Compiler (Williams transfer as a Lean elaborator

**Goal (from the scope expansion, DEC-012):** Formalize **Williams' transfer theorem**(nontrivial CircuitSAT algorithm for class C ⟹ NEXP ⊄ C)as a Lean **elaborator**:feed it a verified algorithm + verified runtime bound, it emits a verified circuit lower bound. This goes under `PleaNP.Circuits` (new `Circuits/` infrastructure, formally layered above the Rung-4 circuit library).

**Design sketch:**
- An elaborator command (e.g. `#lower_bound_compile`) taking: (1) a formally verified CircuitSAT algorithm `sat_c : C → Circuit` (witness:nontriviality proof/ runtime bound proof);(2) the theorem transformer emitting `NEXP ⊄ C` with the dependency closure attaching the verified algorithm's runtime as the bound.
- The transfer is the source of Williams-type lower bounds`NEXP ⊄ ACC⁰` et al.— widest eventual force-multiplier,but not blocking anything earlier.



**Status:** Not started (placeholder note only). Lower priority than #1 — it's the widest force-multiplier eventually,but isn't blocking. Depends on Rung 4(circuit library)+ a verified CircuitSAT algorithm (harvested from Rung 7 benchmark work)..

---

## Rung 9 — AI proof-search loop

**Goal:** Premise-selection + tactic-search over the formalized barrier landscape, bounded by the formalized "don't try X" constraints from Rungs 3–4.

**Integrity constraint:** All proof search runs against *frozen, fidelity-checked* statements only. The gates (see `docs/ARCHITECTURE.md`) are mandatory here — this is where the most integrity risk concentrates.

**Baseline references (from the prior-art review):** build premise-selection on **LeanDojo/ReProver** (or justify divergence); use **LeanDojo Benchmark 4**'s autoformalization metrics (exact-match < 10%, proof-check < 20%) as the *measured* threat model for Gates 3–4. The 2025–2026 prover wave (AlphaProof, DeepSeek-Prover-V2, Goedel-Prover-V2, Kimina-Prover, etc.) all benchmark on *already-correct* statements — none addresses the adversarial statement-fidelity case that is Rung 9's distinguishing challenge (see `docs/PRIOR_ART.md`, AI-tooling section).

**Status:** Not started. Depends on Rungs 3–4, 5, 6.

---

## Rung 10 — Open problems below P vs NP

**Goal:** With the barrier library + search loop in place, attack problems one rung below P vs NP:
- Improved circuit lower bounds (extending Williams-style arguments)
- Derandomization consequences (if certain lower bounds hold, P = BPP)
- Sharpening the P/NP/intermediate structure (Ladner-style)

**Scope note (from the prior-art review):** Williams's *Simulating Time With Square-Root Space* (STOC 2025, `arXiv:2502.17779`) is *already* a Lean formalization target by Reitwiessner (Lean Together 2026) — track that effort and pick a *different* open problem to avoid duplication. Ladner-style structure and derandomization consequences are both open and unclaimed (see `docs/PRIOR_ART.md`).

Each is independently publishable. None is P vs NP, and that's the point.

**Status:** Not started. Depends on Rung 10.

---

## Rung 11 — Novel barrier-evasion arguments

**Goal:** Only after Rungs 1–10 exist, attempt genuinely novel lower-bound or barrier-evasion arguments. The AI's role is constrained search: "given the formalized barrier map, what proof shapes haven't been ruled out?"

**Honest scoping:** Long shot. The barriers exist precisely because evading them is extraordinarily hard. But even if this rung never succeeds, Rungs 1–10 are a complete, valuable research program.

**Status:** Not started. Depends on Rung 10.

---

## What "done" looks like at each rung

| Rung | Done means |
|---|---|
| 1 | `GAP_AUDIT.md` written and reviewed |
| 2 | Oracle machines formalized; P/NP imported from upstream |
| 3 | Relativization + natural-proofs conditional(OWF as hypothesis) + algebrization (AW09 v1) compile, zero `sorry` |
| 4 | AC⁰ lower bounds + Williams formalizedwith barrier-classification proofs |
| 5 | `Relativizing` typeclass + `#barrier_check` elaborated and unit-tested against the time-hierarchy theorem(DEAD)and a non-relativizing control(Inconclusive) |
| 6 | Machine-checked P/NP model-equivalence anchor + `P_eq_NP_iff` rendered via explicit `#eval`-able Levin-search term;search⟶decision gap lemma stated/scoped |
| 7 | Benchmark suite exists with baseline AI measurements |
| 8 | Williams transfer elaborator (`#lower_bound_compile`) emits verified `NEXP ⊄ C` given a verified CircuitSAT algorithm + runtime bound |
| 9 | Search loop solves ≥1 Rung-7 task end-to-end through the gates, benchmarked against LeanDojo/ReProver |
| 10 | ≥1 open problem below P vs NP formally proven (excluding Williams √-space, already targeted by Reitwiessner) |
| 11 | A candidate barrier-evasion argument, gate-validated |
