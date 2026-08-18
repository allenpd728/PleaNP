# Statement spec: Natural proofs (Razborov–Rudich, 1994)

**Rung:** 3b — the second barrier to formalize (`docs/GAP_AUDIT.md` §6, prioritization §3; `docs/ROADMAP.md` Rung 3).
**Status:** Draft scaffold — the informal-to-formal mapping is pinned; the Lean rendering is the local agent's job. This document is the Gate 1 frozen-statement anchor and the Gate 4 read-back reference. It must not be edited by any proof-search pipeline.

---

## 1. Informal statement

**Source:** Razborov, A., Rudich, S. *Natural Proofs.* Journal of Computer and System Sciences 55(1):24–35, 1997 (STOC '94; Gödel Prize 2007). Cited in `docs/PRIOR_ART.md` as the informal source of truth for Gate 4.

The barrier is a **conditional** theorem, not an unconditional one. Its dependence on an unproven cryptographic assumption is central to the spec (see §3).

> **(Main theorem, informal):** If **strong one-way functions exist** (equivalently, pseudorandom function families exist with exponential hardness), then there is **no** `P`-natural (or `NP`-natural) property that is useful against `P/poly` for proving superpolynomial circuit lower bounds.

Equivalently: under the existence of sufficiently hard pseudorandom functions, *no proof technique that is "natural"* — meaning it satisfies the constructivity and largeness conditions below — *can yield superpolynomial lower bounds against general polynomial-size circuits.*

### The three defining conditions of a "natural property"

A property is a sequence `C = {C_n}` of subsets of the set `F_n` of Boolean functions on `n` inputs. `C` is a **natural property** against a class `C` (the complexity class, confusingly also called `C` in the original — here we call the class `𝒞` to disambiguate) if:

1. **Usefulness against 𝒞.** For any sequence of functions `{f_n}` where `f_n ∈ C_n` holds infinitely often, `{f_n}` is not in `𝒞` (i.e., membership in the property rules the function out of the target class). This is the *trivial* requirement — a lower-bound proof must rule the function out of the class.
2. **Constructivity.** The predicate "is `f ∈ C_n`?" is decidable in `𝒫` (polynomial time in the size of the truth table, i.e. in `2^n`). The constructivity class can be relaxed; the original uses `P`-natural (`poly(2^n)`-time) or `NP`-natural.
3. **Largeness.** For all large enough `n`, `C_n` contains at least a `1/2^n` fraction (or, in the density-`δ` generalization, a `2^{-δn}` fraction) of all functions in `F_n`. I.e., a *random* function is in `C_n` with non-negligible probability.

The barrier: under the hardness assumption, no property satisfying (2) and (3) can be useful (1) against `P/poly`.

**Barrier consequence:** Almost all known non-monotone circuit lower-bound techniques (parity ∉ AC⁰, etc.) are natural — they exhibit constructivity and largeness. Hence, under the standard cryptographic assumption, they provably cannot lift to superpolynomial lower bounds for general circuits, i.e., cannot resolve P vs NP.

---

## 2. Dependencies (where each definition must come from)

| Definition | Source | Status |
|---|---|---|
| Boolean function / truth table | Upstream Mathlib (`Bool`, `List`, finitary structures) | Present |
| **Boolean circuits, `P/poly`** | **PleaNP-local** (`PleaNP.Circuits`, Rung 4) — no Mathlib circuit model | Blocked on Rung 4 substrate; complexitylib (#6) has a circuit model if importable |
| Circuit size / superpolynomial lower bound | PleaNP-local (Rung 4) | Blocked on circuits |
| **One-way function (OWF)**, **pseudorandom function family (PRFF)** | **PleaNP-local — enters as a *hypothesis***. See `docs/PRIOR_ART.md` (crypto-substrate section): no importable Lean/Coq/Isabelle OWF/PRF exists; EasyCrypt is Coq-ecosystem and game-based, not the bare complexity-theoretic object. | **Unblocked** as a hypothesis (see §3) |
| Polynomial time `P` | Upstream Mathlib (Rung 2, blocked on model) | Blocked on the model |
| `F_n` (the `2^{2^n}`-element set of n-ary Boolean functions) | Mathlib / PleaNP-local | Present |

**Key scope clarification (from `docs/ROADMAP.md` Rung 3b):** PleaNP formalizes the **conditional** (`OWF exists ⟹ …`), so the OWF/PRFF enters as a **hypothesis**, not a constructed object. PleaNP does **not** build a PRF. This is a meaningful simplification: the open cryptographic assumption is assumed, not proven, exactly as in the informal theorem.

---

## 3. Formalization target (statement shape — no Lean rendering)

Pinned to the **Razborov–Rudich 1997 conditional** (per `docs/ROADMAP.md`: OWF-as-hypothesis). The actual Lean rendering is the local agent's job. The *logical shape*:

**Main theorem.** *If* one-way functions exist (with exponential hardness — the exact hardness parameter is a scope item, §7), *then* no `P`-natural property (constructivity + largeness) is useful against `P/poly` for superpolynomial lower bounds.

**Acceptance criteria the Lean rendering must encode:**
- This is a **conditional / implication**, `OWF_hypothesis ⟶ barrier_conclusion`. The OWF **must** appear as an explicit hypothesis (a `variable` / ` hypothesis` / assumed type), never constructed. A formalization that constructs a concrete PRF has proven a *different* (and far stronger) statement — a Gate 5 (non-triviality) concern and a scope violation.
- "Natural property" must encode **all three** conditions (usefulness, constructivity, largeness); a formalization dropping largeness or constructivity is a *weaker* claim (and, per Fortnow's critique in `docs/PRIOR_ART.md` search, constructivity is precisely the debatable one — but the original theorem includes it, so the v1 statement keeps it).
- The conclusion is a **negation**: "there does not exist a natural property useful against `P/poly` for superpoly lower bounds." Confirm the Lean expresses non-existence, not just "no known proof."
- The hardness parameter (exponential hardness of the PRFF) must be explicit, not hand-waved; the barrier's strength depends on it. See §7.
- Namespace: `PleaNP.Barriers.NaturalProofs` (per DEC-002).
- Dependencies: `PleaNP.Circuits` (for `P/poly`, circuit size) — so this spec is blocked on Rung 4 circuit substrate, unlike relativization (3a) which depends only on Rung 2 oracles.

---

## 4. Gate mapping (which integrity gates apply, and what each checks here)

Reference: `docs/ARCHITECTURE.md`.

| Gate | What it checks for *this* statement | Failure mode it blocks |
|---|---|---|
| **1 — Statement-freeze** | This spec is version-controlled and read-only to proof search. | Quietly weakening the largeness/constructivity conditions until the theorem is vacuous. |
| **2 — Model-consistency** | `P/poly`, circuits reference canonical upstream/`PleaNP.Circuits` defs, not local redefinitions. | Redefining `P/poly` to a class the proof trivially avoids. |
| **3 — Statement-fidelity** | A second, independent formalization of RR must be logically equivalent. | One formalization quietly dropping the constructivity condition. |
| **4 — Read-back** | An auto-generated informal statement read back from the Lean must match §5. | Statement compiles but expresses an unconditional result, or drops the hardness parameter. |
| **5 — Non-triviality** | The OWF enters as a genuine hypothesis (not provable from the axioms); the conditional is not vacuously true. | Proving `OWF_hypothesis ⟶ True` (vacuous) by sneaking the conclusion into the hypothesis. |
| **6 — Hygiene** | The proof scans for `sorry`/`admit`/custom axioms — *especially* a hidden "OWFs exist" axiom smuggled in as if proven. | A "proof" that assumes what it should hypothesize. |

**Gate 5 specifics (the OWF trap):** Because the OWF is an open conjecture, the single most likely integrity failure is treating it as proven rather than hypothesized. The linter/gate must verify the OWF is a `variable`/`hypothesis`, not a `theorem`/`axiom` dressed as one.

---

## 5. Read-back check (Gate 4 acceptance criterion)

The formal Lean statement, translated back to natural language, must produce a sentence equivalent to:

> *"Under the assumption that one-way functions (equivalently, pseudorandom function families of exponential hardness) exist, no property that is constructive (decidable in time polynomial in the size of the truth table) and large (containing a non-negligible fraction of all Boolean functions) can be useful — i.e., can witness functions outside P/poly — for proving superpolynomial circuit-size lower bounds."*

**Disagreement blocks the claim.** Specifically, a read-back that drops any of these is a fail:
- "under the assumption that one-way functions exist" (dropping it makes the result unconditional — a different, false theorem);
- "constructive" *and* "large" (dropping either weakens the statement);
- "superpolynomial" (dropping it changes the lower-bound strength);
- the explicit hardness parameter on the OWF/PRFF.

---

## 6. Prior art and references

- **Source paper:** Razborov & Rudich, *Natural Proofs*, JCSS 55(1):24–35, 1997 (STOC '94; Gödel Prize 2007).
- **Textbook treatment:** Arora–Barak §23 (the definitional source complexitylib follows, per `UPSTREAM_TRACKING.md` §6); also the MIT 6.875 / Boaz Barak ch.4 notes on PRFs.
- **Closest existing formalizations** (`docs/PRIOR_ART.md`, cross-assistant survey): none — no proof assistant formalizes natural proofs. complexitylib (#6) has a Fourier-analysis-of-Boolean-functions subtheory (O'Donnell ch.1), the analytic foundation for small-depth lower bounds and natural proofs — potentially reusable substrate for the circuit side, but it does *not* contain OWF/PRF or the barrier theorem itself.
- **Crypto-substrate finding** (`docs/PRIOR_ART.md`): no importable Lean/Coq/Isabelle OWF/PRF exists — confirms the OWF must be a hypothesis, not an import.
- **The constructivity debate** (Lance Fortnow, "Natural Proofs is Not the Barrier You Think It Is," 2024, in `docs/PRIOR_ART.md` search): argues constructivity is the artificial condition. This is a *theoretical* critique, not a formalization precedent — the v1 statement keeps constructivity per the original; the debate is tracked, not folded in.

---

## 7. What this spec does NOT yet resolve (open for the Lean author / Rung 4)

These are deliberately open; they are downstream design tasks, not statement-fidelity questions:

1. **The exact hardness parameter.** Razborov–Rudich require the PRFF to be `2^{n^ε}`-hard for some `ε > 0` (exponential hardness). The precise `ε` and the formalization of "hardness" (distinguishing-advantage form) is a Lean-author decision; the spec requires only that it be *explicit*, not hand-waved.
2. **`P/poly` rendering** — nonuniform polynomial-size circuits. Depends on `PleaNP.Circuits` (Rung 4) existing; complexitylib's circuit model is a candidate import.
3. **The constructivity class** — original uses `P`-natural (`poly(2^n)`-time). `NP`-natural is a known variant; v1 pins `P`-natural per the original.
4. **Largeness density** — `1/2^n` (original) vs `2^{-δn}` (density-`δ` generalization). v1 pins the original `1/2^n`.

These do not affect the frozen informal statement in §1; they affect only its Lean rendering, checked against §5.
