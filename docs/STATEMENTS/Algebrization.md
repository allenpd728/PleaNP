# Statement spec: Algebrization (Aaronson–Wigderson, 2008)

**Rung:** 3c — the third and most intricate barrier to formalize (`docs/GAP_AUDIT.md` §7, prioritization §4; `docs/ROADMAP.md` Rung 3).
**Status:** Draft scaffold — the informal-to-formal mapping is pinned; the Lean rendering is the local agent's job. This document is the Gate 1 frozen-statement anchor and the Gate 4 read-back reference. It must not be edited by any proof-search pipeline.

---

## 1. Informal statement

**Source:** Aaronson, S., Wigderson, A. *Algebrization: A New Barrier in Complexity Theory.* ACM Transactions on Computation Theory 1(1), 2009 (STOC '08; ECCC TR08-005). Cited in `docs/PRIOR_ART.md` as the informal source of truth for Gate 4.

**v1 pin (per `docs/ROADMAP.md` Rung 3c):** this spec pins the **original Aaronson–Wigderson 2009 (multiquadratic) formulation** as the v1 target. The ITCS 2026 multilinear-strengthening (`docs/PRIOR_ART.md`, "Recent theoretical refinements") is tracked as a candidate v2, **not** folded into v1 — prevents formalizing a moving folk theorem.

The barrier refines relativization and natural proofs. Its core idea: when relativizing a complexity class inclusion, the simulating machine should get access not only to an oracle `A`, but also to a **low-degree extension of `A` over a finite field**.

> **(Algebrization barrier, informal):** A lower-bound or class-separation result *algebrizes* if, for every oracle `A` and every low-degree extension `Ã` of `A`, the (relativized-with-`A`) result still holds when the simulating machine is given oracle access to `Ã`. Aaronson–Wigderson show that (a) all known non-relativizing results based on arithmetization (IP=PSPACE, MIP=NEXP, MAEXP ⊄ P/poly) algebrize; and (b) almost all major open problems — including P vs NP, P vs RP, NEXP vs P/poly — require **non-algebrizing** techniques.

### The two algebrization results most directly relevant to P vs NP

For the v1 statement, the relevant algebrization results (Aaronson–Wigderson 2009, Theorem 3.17 and surrounding) are:

- **There exists an oracle `A` and a low-degree extension `Ã` of `A` such that `NP^A ⊄ P^Ã`.** This is the analogue of BGS clause (b): it rules out algebrizing proofs of `P = NP` (since `NP^A ⊄ P^Ã` would have to hold).
- Symmetrically, there exist oracles on the "equalizing" side, so algebrizing proofs of `P ≠ NP` are also blocked.

So algebrization, like relativization, is a **both-sides oracle existence result**: algebrizing techniques cannot separate P from NP because there are `(A, Ã)` pairs witnessing both `P^A = NP^A`-style and `P^B ≠ NP^B`-style outcomes (under the algebrizing access model).

### What "low-degree extension" means

For an oracle `A = {A_m}` where `A_m : {0,1}^m → {0,1}`, its **multilinear extension** over a finite field `F` (with `|F| > m`) is the unique multilinear polynomial `Ã_m : F^m → F` that agrees with `A_m` on `{0,1}^m`. The v1 spec pins the **multiquadratic** formulation used in the original AW09 paper (the multilinear refinement is the ITCS 2026 v2 candidate, not v1).

---

## 2. Dependencies (where each definition must come from)

| Definition | Source | Status |
|---|---|---|
| Oracle machines, `P^A`, `NP^A` | **PleaNP-local** (Rung 2 / `PleaNP.Oracles`) — same as relativization | Unblocked; shared with 3a |
| **Low-degree extension `Ã` of an oracle `A`** | **PleaNP-local** — multilinear/multiquadratic polynomial extension over a finite field | **Blocked on** PleaNP's finite-field substrate + oracle machines |
| Finite fields `F` | Upstream Mathlib (`Mathlib.Data.Fin.Basic`, `Mathlib.RingTheory` etc.) | Present |
| Multilinear polynomials / polynomial evaluation | Upstream Mathlib (`Mathlib.Polynomial`, multilinear structure) | Largely present; the *extension construction* is PleaNP-local |
| `P`, `NP` | Upstream Mathlib (Rung 2) | Blocked on the model |

**Dependency note (from `docs/GAP_AUDIT.md` §7):** algebrization is the most technically intricate of the three to formalize, requiring both oracle machines (shared with 3a) *and* the low-degree-extension machinery over finite fields. It depends on Rung 3a's relativization work being in place.

---

## 3. Formalization target (statement shape — no Lean rendering)

Pinned to the **AW09 multiquadratic formulation** (v1). The actual Lean rendering is the local agent's job. The *logical shape*:

**Clause (a) — algebrizing separation witness.** There exist an oracle `A` and a low-degree (multiquadratic) extension `Ã` of `A` such that `NP^A ⊄ P^Ã`.
**Clause (b) — algebrizing equalization witness.** There exist an oracle `B` and a low-degree extension `B̃` of `B` such that `P^B = NP^B̃` (the equalizing side — exact form per AW09 Theorem 3.17).

**Barrier consequence:** Any algebrizing proof technique cannot resolve P vs NP, because (a) and (b) witness both sides under the algebrizing access model.

**Acceptance criteria the Lean rendering must encode:**
- The oracle `A`/`B` **and** its extension `Ã`/`B̃` are both *existential* and appropriately *computable/recursive* (per AW09's recursive oracle constructions — same non-triviality concern as relativization, Gate 5).
- `Ã` is the **multiquadratic** extension in v1 (per the rung pin); the multilinear refinement is explicitly a v2 candidate, tracked in `docs/PRIOR_ART.md`, *not* part of this statement.
- The access model is precise: the simulating machine gets access to `Ã` (the extension), not just `A`. This is the distinguishing feature vs. plain relativization. A formalization that gives the simulator access only to `A` has formalized *relativization*, not algebrization — a Gate 3/4 failure.
- `NP^A ⊄ P^Ã` is strict non-containment (not equality-negation of classes — the access is asymmetric: the `NP` side gets `A`, the `P` simulator gets `Ã`). Confirm this asymmetry is encoded; it is the crux of the barrier.
- Namespace: `PleaNP.Barriers.Algebrization` (per DEC-002).
- Dependencies: `PleaNP.Oracles` (shared with 3a) + finite-field extension machinery.

---

## 4. Gate mapping (which integrity gates apply, and what each checks here)

Reference: `docs/ARCHITECTURE.md`.

| Gate | What it checks for *this* statement | Failure mode it blocks |
|---|---|---|
| **1 — Statement-freeze** | This spec is version-controlled and read-only to proof search. | Quietly collapsing the `Ã` access to plain `A` access (silently reverting to relativization). |
| **2 — Model-consistency** | Oracles, `P`/`NP`, finite fields reference canonical defs; the extension is the canonical multiquadratic construction, not a local shortcut. | Replacing the low-degree extension with the identity (which collapses algebrization to relativization). |
| **3 — Statement-fidelity** | A second, independent formalization of AW09 must be logically equivalent. | One formalization encoding symmetric `A`-access instead of asymmetric `(A, Ã)`-access. |
| **4 — Read-back** | An auto-generated informal statement read back from the Lean must match §5. | Statement compiles but gives the simulator access to `A` not `Ã`, or drops the multiquadratic pin. |
| **5 — Non-triviality** | The oracle + extension are recursive; the statement isn't vacuous. | Proving a trivial containment by abusing the extension's freedom. |
| **6 — Hygiene** | Scans for `sorry`/custom axioms. | A "proof" that compiles via a hidden extension-definition shortcut. |

**Gate 2 specifics (the collapse-to-relativization trap):** The single most likely integrity failure for algebrization is the low-degree extension being weakened (e.g. to the identity, or to `A` itself) so the statement collapses to plain relativization. The linter must verify `Ã` is a genuine low-degree extension distinct from `A`'s pointwise restriction.

---

## 5. Read-back check (Gate 4 acceptance criterion)

The formal Lean statement, translated back to natural language, must produce a sentence equivalent to:

> *"There exist a recursive oracle A and a multiquadratic (low-degree) extension Ã of A over a finite field, such that NP^A is not contained in P^Ã; and there exist a recursive oracle B and a low-degree extension B̃ of B such that P^B = NP^B̃. Therefore any proof technique that algebrizes — i.e., that continues to hold when the simulating machine is given access to a low-degree extension of the oracle — cannot resolve P versus NP."*

**Disagreement blocks the claim.** Specifically, a read-back that drops any of these is a fail:
- "low-degree extension Ã" (dropping it, or replacing with "A", collapses to relativization);
- the **asymmetric access** — `NP^A` vs `P^Ã` (symmetric access is a different, weaker statement);
- "multiquadratic" in v1 (the multilinear refinement is v2, not v1);
- "recursive" on both oracle and extension (noncomputable witnesses are a different theorem).

---

## 6. Prior art and references

- **Source paper:** Aaronson & Wigderson, *Algebrization: A New Barrier in Complexity Theory*, ACM TOCT 1(1), 2009 (STOC '08; ECCC TR08-005). `www.math.ias.edu/~avi/PUBLICATIONS/ABSTRACT/aw08ab.pdf`.
- **Textbook treatment:** Arora–Barak §23 (definitional source, per `UPSTREAM_TRACKING.md` §6).
- **Closest existing formalizations** (`docs/PRIOR_ART.md`, cross-assistant survey): none — no proof assistant formalizes algebrization. This is the most intricate of the three to formalize (GAP_AUDIT §7).
- **ITCS 2026 refinement** (`docs/PRIOR_ART.md`, "Recent theoretical refinements"): *New Algebrization Barriers to Circuit Lower Bounds via Communication Complexity of Missing-String* — strengthens AW09's multiquadratic barrier to *multilinear* extensions. **Tracked as v2 candidate; explicitly NOT part of the v1 statement.** The local agent must not fold this in.
- **Interaction with Williams √-space** (`docs/PRIOR_ART.md`): any `P ≠ PSPACE` proof must be non-algebrizing; Williams's STOC 2025 result is a candidate ingredient — relevant context, not a v1 dependency.
- **"Semi-relativization"** (arXiv:2601.09702): claims to evade all three barriers. Treat as a Rung 8 test case, NOT as part of this v1 statement.

---

## 7. What this spec does NOT yet resolve (open for the Lean author / Rungs 2 & 3a)

These are deliberately open; they are downstream design tasks, not statement-fidelity questions:

1. **The exact field `F` and its size relative to `m`** — AW09 require `|F|` large enough (e.g. `> m`) for the multiquadratic extension to be well-defined and to support the simulations. The precise field choice is a Lean-author decision; the spec requires only that it be explicit and that the extension be genuinely low-degree.
2. **The exact form of clause (b)** (the equalizing side) — AW09's Theorem 3.17 and surrounding give the precise containment/equality; the spec pins the *existence of both sides* but the exact equality form (`P^B = NP^B̃` vs a containment variant) follows AW09's theorem statement, to be rendered faithfully by the local agent.
3. **Composition with the relativization formalization (3a)** — algebrization reuses `PleaNP.Oracles`; the local agent must verify the oracle types compose with the extension machinery. This is a Rung 2/3a design task.
4. **The multilinear (v2) strengthening** — explicitly out of scope for v1; tracked separately in `docs/PRIOR_ART.md`.

These do not affect the frozen informal statement in §1; they affect only its Lean rendering, checked against §5.
