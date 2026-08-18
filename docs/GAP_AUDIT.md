# Gap audit: Mathlib complexity coverage vs. the barrier theorems

**Rung 1 deliverable.** This is the spec for Rungs 2–4. It catalogues, domain by domain, what Mathlib currently has for complexity theory and what the barrier theorems (relativization, natural proofs, algebrization) require.

Last reviewed: 2026-08-18. Update when upstream lands (see `docs/UPSTREAM_TRACKING.md`).

---

## Executive summary

Mathlib has **computability** (Turing machines, computable functions, partial computability) but essentially **no complexity theory** — no P, no NP, no reductions, no complexity classes as objects, no oracles, no circuit complexity, no proof complexity, and none of the three barriers.

The complexity substrate is being actively built by 3–4 upstream efforts (tracked in `docs/UPSTREAM_TRACKING.md`), none of which has landed in Mathlib core yet. Once one lands, PleaNP imports it and fills the gaps none of them cover: oracles, the barriers, circuit complexity, and proof complexity.

**The barrier theorems are open ground in every proof assistant, in every model.** That is PleaNP's core contribution.

---

## Domain-by-domain analysis

### 1. Computational model

| Need | Mathlib status | Gap |
|---|---|---|
| A Turing machine model with step counting | `Mathlib/Computability/TuringMachine.lean` defines `TM0`, `TM1`, `TM2` (Carneiro 2018), but with **no step counting or time bounds** | Missing: `runN` / `EvalsToInTime` style time measures |
| Model equivalence (invariance thesis) | Not formalized | Missing: TM ↔ λ-calculus polynomial overhead |
| Choice of canonical model | Not settled | Contested — see `docs/UPSTREAM_TRACKING.md` |

**PleaNP stance:** Import from upstream. Do not pick a side. The model is upstream's problem (Rung 2).

### 2. Complexity classes

| Need | Mathlib status | Gap |
|---|---|---|
| `P` (polynomial time) | Not defined | Missing entirely |
| `NP` (nondeterministic poly time / poly-time verifiable) | Not defined | Missing entirely |
| `P ⊆ NP` | Not provable (no definitions) | Missing |
| NP-hardness, NP-completeness | Not defined | Missing |
| Polynomial-time reductions | Not in Mathlib (Simas 2026 does it standalone) | Missing from core |

**PleaNP stance:** Import from upstream (#35366 or #33132, whichever lands). Do not define locally.

### 3. Oracle machines (relativization substrate)

| Need | Mathlib status | Gap |
|---|---|---|
| Oracle TMs (TM + oracle tape answering a fixed function in 1 step) | Not present | **Missing entirely — PleaNP builds this** |
| Oracle complexity classes P^A, NP^A | Not present | **Missing — PleaNP builds this** |
| Oracle-separation results (Baker-Gill-Solovay) | Not present | **Missing — Rung 3** |

**PleaNP stance:** This is ours regardless of which upstream model lands. None of the 4 tracked efforts provide oracle machines. Lives under `PleaNP.Oracles` / `PleaNP.Barriers.Relativization`.

### 4. Relativization barrier (Baker-Gill-Solovay 1975)

| Need | Mathlib status | Gap |
|---|---|---|
| "There exists oracle A with P^A = NP^A" | Not formalized anywhere | **Rung 3 — open ground** |
| "There exists oracle B with P^B ≠ NP^B" | Not formalized anywhere | **Rung 3 — open ground** |
| The barrier statement (relativizing proofs can't separate P from NP) | Not formalized anywhere | **Rung 3 — open ground** |

**Note:** This is the most foundational barrier and the one with the cleanest formalization target (it's an existence result about oracles, not a deep property of proof techniques).

### 5. Circuit complexity

| Need | Mathlib status | Gap |
|---|---|---|
| Boolean circuits (uniform family) | Not present | Missing entirely |
| AC⁰ (constant-depth, AND/OR/NOT circuits) | Not present | Missing |
| TC⁰ (AC⁰ + threshold gates) | Not present | Missing |
| NC hierarchy | Not present | Missing |
| Switching lemma (Håstad) | Not present | Missing |
| Parity ∉ AC⁰ | Not present | **Rung 4** |
| Monotone circuit lower bounds (Razborov) | Not present | **Rung 4** |
| ACC⁰ (Williams NEXP ⊄ ACC⁰, 2011) | Not present | **Rung 4 — the barrier-evading existence proof** |

**PleaNP stance:** Build under `PleaNP.Circuits`. Large gap but defined work. Williams's result is the existence proof that barrier-evading techniques exist, so it's the morale/methodology anchor.

### 6. Natural proofs barrier (Razborov-Rudich 1994)

| Need | Mathlib status | Gap |
|---|---|---|
| Pseudorandom function families (PRFFs) | Not present (some crypto may exist) | Missing |
| One-way functions (OWFs) | Not present | Missing |
| Natural property (constructivity + largeness + usefulness) | Not present | **Rung 3 — open ground** |
| The barrier (OWF exists ⟹ no natural proof gives superpoly lower bounds) | Not formalized anywhere | **Rung 3 — open ground** |

**Dependencies note:** Natural proofs requires pseudorandom functions and one-way functions as prerequisites. These are cryptography-adjacent and may overlap with existing Mathlib crypto. The gap audit should verify whether Mathlib's cryptography infrastructure can serve as a base.

### 7. Algebrization barrier (Aaronson-Wigderson 2008)

| Need | Mathlib status | Gap |
|---|---|---|
| Low-degree extensions of oracles over finite fields | Not present | Missing |
| Algebrizing simulations | Not present | **Rung 3 — open ground** |
| The barrier statement | Not formalized anywhere | **Rung 3 — open ground** |

**Dependencies note:** Requires finite fields (Mathlib has these) and oracle machines (Rung 2/PleaNP-local). This barrier is the most technically intricate of the three to formalize.

### 8. Proof complexity

| Need | Mathlib status | Gap |
|---|---|---|
| Resolution proof system (size, width) | Not present | Missing |
| Frege systems | Not present | Missing |
| PCP theorem (full, not just a slice) | Not present (some PCP-adjacent crypto exists) | **Rung 4** |
| Hardness vs. randomness | Not present | Rung 4 |

**PleaNP stance:** Build under `PleaNP.ProofComplexity`. Lower priority than the barriers and circuit complexity but needed for the full picture.

### 9. Reductions and NP-completeness

| Need | Mathlib status | Gap |
|---|---|---|
| Polynomial-time many-one reductions | Not in core (Simas standalone) | Import from upstream |
| Cook-Levin (SAT NP-complete) | Not in Mathlib (done in Coq, Isabelle) | Import or rebuild if upstream lacks it |
| Karp's 21 problems | Not present | descriptive-complexity (Senellart) covers these |

---

## Prioritization for Rungs 2–4

Given the gap analysis, the build order is:

1. **Rung 2:** Import P/NP/reductions from upstream (track `UPSTREAM_TRACKING.md`). Build oracle machines locally (no upstream covers this). *Status: blocked on upstream landing, but oracle machines can be prototyped against a chosen model.*

2. **Rung 3a:** Relativization (Baker-Gill-Solovay) — cleanest target, depends only on oracle machines (which we build) + P/NP (upstream). **This is the first barrier to formalize.**

3. **Rung 3b:** Natural proofs (Razborov-Rudich) — depends on PRFFs/OWFs + circuit complexity basics. More prerequisites.

4. **Rung 3c:** Algebrization (Aaronson-Wigderson) — depends on relativization + finite fields. Most intricate.

5. **Rung 4:** Circuit lower bounds + Williams, classified by which barriers they evade. Builds on Rung 3.

---

## What the audit tells us about scope

- **Rung 2 is smaller than feared** — upstream is building the substrate; we import and add oracles.
- **Rung 3 is the real work** — three theorems, none formalized anywhere, all open ground. This is the multi-year core contribution.
- **Rung 4 is large but defined** — circuit complexity is essentially absent from Mathlib, but the targets are known theorems with known proofs.
- **The barriers (Rung 3) require Rung 2's oracle machines and Rung 4's circuit basics as prerequisites** — the dependency is: oracles → relativization; circuits + PRFFs → natural proofs; oracles + finite fields → algebrization.

---

## Open questions to resolve

1. Does Mathlib's existing cryptography infrastructure provide a base for pseudorandom functions / one-way functions (needed for natural proofs)? *To verify.*
2. When P/NP lands upstream, does the chosen model make oracle-machine definition tractable? If not, evaluate the synthetic approach (Church's Thesis as axiom).
3. Is there overlap with the `descriptive-complexity` approach (Senellart) for NP-completeness results, even though it avoids machines?
