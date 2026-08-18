# Informal proof strategy: Natural proofs (Razborov–Rudich)

**Rung:** 3b — informal proof-strategy outline for `docs/STATEMENTS/NaturalProofs.md`.
**Status:** **Informal strategy — NOT a frozen proof spec.** Preparatory doc, sourced to the literature. Explicitly *not* a Gate-1 frozen target. The frozen proof spec is written only after the natural-proofs statement is rendered against real types (`P/poly`, circuits, the OWF hypothesis) and Gates 1–5 pass. This doc informs without binding, and does not jump `LOCAL_AGENT_WORKFLOW.md` Step 6.

---

## 1. What this doc is and is not

- **Is:** an informal outline of how Razborov–Rudich 1994 is proved, so the eventual proof spec can be written fast against a known strategy.
- **Is not:** a frozen proof spec; a Lean rendering target; a substitute for `NaturalProofs.md` (the statement); or a Gate-1 artifact.

**Integrity constraint:** same as the relativization strategy doc — the docs agent writes the informal strategy; the frozen proof spec comes after statement freeze; proof search (Step 6) is gated. This doc sits before that gate, as preparation.

---

## 2. The structure of the theorem (recap)

Per `NaturalProofs.md` §1, the theorem is a **conditional**: *if* one-way functions exist (equivalently, pseudorandom function families of exponential hardness exist), *then* no `P`-natural property (constructive + large) is useful against `P/poly` for superpolynomial lower bounds.

So the proof has two halves:
1. **The crypto half:** from the OWF/PRFF assumption, construct a pseudorandom function family `{f_s}` that is indistinguishable from random by any polynomial-time algorithm given oracle access.
2. **The barrier half:** show that any `P`-natural property useful against `P/poly` would yield a polynomial-time distinguisher between `{f_s}` and a truly random function — contradicting the pseudorandomness.

The proof is a *reduction*: natural-property-as-distinguisher → contradiction with PRFF pseudorandomness.

---

## 3. The proof strategy (sourced to Razborov–Rudich 1997; Arora–Barak §23)

### Half 1 — the cryptographic primitive (assumed, not constructed)

**Key simplification (per `NaturalProofs.md` §3):** PleaNP formalizes the *conditional*, so the OWF/PRFF enters as a **hypothesis**, not a constructed object. PleaNP does not build a PRF; it *assumes* one exists with exponential hardness. This is the single biggest scope reduction vs. the underlying crypto:

- The hypothesis is: there exists a PRFF `{f_s : {0,1}^n → {0,1}}` (seeded by `s`) such that no polynomial-time adversary `A` with oracle access can distinguish `f_s` (for random `s`) from a truly random function `R : {0,1}^n → {0,1}` with non-neglible advantage. "Exponential hardness" = the PRFF is `2^{n^ε}`-hard for some `ε > 0`.
- **PleaNP does NOT prove the HILL theorem** (Håstad-Impagliazzo-Levin-Luby: OWF → PRG → PRF). That's deep crypto and out of scope. The conditional takes the PRFF as given.

### Half 2 — the reduction (natural property → distinguisher)

This is the actual barrier argument and the core of the proof. The strategy:

1. **Assume** a `P`-natural property `C = {C_n}` exists that is useful against `P/poly` (i.e., any function with property `C_n` infinitely often is outside `P/poly`). By "natural," `C` is:
   - **Constructive:** "is `f ∈ C_n`?" is decidable in `poly(2^n)` time (polynomial in the truth-table size).
   - **Large:** `C_n` contains at least a `1/2^n` fraction of all `2^{2^n}` functions (a non-negligible fraction).
2. **Build a distinguisher `D`** that uses `C` to tell `f_s` (pseudorandom) from `R` (random):
   - Given oracle access to a function `g` (either `f_s` or `R`), query `g` on all `2^n` inputs to get its truth table.
   - Check whether `g`'s truth table is in `C_n` (this is the *constructivity* of `C` — it's decidable in `poly(2^n)` time, and we have the full truth table from the queries).
   - If yes, guess "g is random" (R); if no, guess "g is pseudorandom" (f_s).
3. **Why this distinguishes:**
   - A truly random function `R` is in `C_n` with non-negligible probability (by *largeness* of `C`). So `Pr[D(R) = "random"] ≥ 1/2^n` — D says "random" often on R.
   - A pseudorandom `f_s` is *never* in `C_n` for large enough `n` — because `f_s` is computable by a small circuit (the PRFF construction gives poly-size circuits), and `C` is *useful against `P/poly`*, so any function in `C_n` infinitely often is *not* in `P/poly`, hence not computable by small circuits. So `f_s ∉ C_n`, and `D(f_s) = "pseudorandom"` always.
   - Thus `D` distinguishes `f_s` from `R` with non-negligible advantage — contradicting the PRFF's pseudorandomness.
4. **Conclusion:** the assumed natural property `C` cannot exist (under the OWF/PRFF hypothesis).

### The crux moves

- **Constructivity → distinguisher's test.** The property being poly-time decidable on the truth table is *what makes it usable as a distinguisher*. This is why the barrier targets *natural* (constructive) properties specifically.
- **Largeness → random functions pass.** The property holding for a non-negligible fraction of random functions is what gives D non-negligible advantage on R.
- **Usefulness → pseudorandom functions fail.** The property ruling out `P/poly` functions is what makes `f_s` (which has small circuits) fail the test.

All three conditions are load-bearing; drop any one and the reduction breaks. This is why the statement spec (`NaturalProofs.md` §3) requires all three be encoded.

---

## 4. Formalization difficulty and dependencies (informal estimate)

| Element | Difficulty | Dependency |
|---|---|---|
| OWF/PRFF hypothesis (as assumption) | Easy — it's a `variable`/`hypothesis` | None (it's assumed) |
| `P/poly` (nonuniform poly-size circuits) | Moderate — nonuniform circuit model | `PleaNP.Circuits` (Rung 4); complexitylib's circuit model is a candidate import |
| Circuit size / superpoly lower bound | Moderate | Circuit model |
| Natural property (3 conditions) | Moderate — three predicates, each formal | `P/poly` + constructivity (poly-time in `2^n`) |
| The distinguisher `D` construction | **Hard** — query all `2^n` inputs, run C's test, output decision | Natural property + circuit model |
| The contradiction (PRFF pseudorandomness) | Moderate — use the assumed PRFF's indistinguishability | The PRFF hypothesis + the distinguisher |
| Hardness parameter (`2^{n^ε}`-hard) | Must be explicit, not hand-waved (`NaturalProofs.md` §7) | The hypothesis |

**Honest read:** this is *more* prerequisite-heavy than relativization. It needs `P/poly` and circuit size (Rung 4 substrate), which don't exist yet and aren't on the current critical path. The proof itself is a clean reduction once the substrate is there, but the substrate is larger. This is why ROADMAP orders 3b *after* 3a — relativization needs only oracles; natural proofs needs oracles + circuits + crypto.

---

## 5. Open proof-strategy questions (for the eventual frozen proof spec)

1. **`P/poly` rendering.** Nonuniform polynomial-size circuits. complexitylib has a circuit model (UPSTREAM_TRACKING §6); PleaNP's `PleaNP.Circuits` is a stub (Rung 4). Which is the import path? Blocked on circuit substrate existing.
2. **The hardness parameter.** Razborov–Rudich require `2^{n^ε}`-hardness for some `ε > 0`. The exact `ε` and the formalization of "hardness" (distinguishing-advantage form) is a Lean-author decision; the statement requires it be *explicit* (`NaturalProofs.md` §7).
3. **Constructivity class.** v1 pins `P`-natural (`poly(2^n)`-time). `NP`-natural is a known variant; the original theorem uses `P`-natural. The proof's distinguisher runs in `poly(2^n)` time, which matches `P`-natural constructivity — so the v1 pin is consistent with the proof strategy.
4. **Largeness density.** v1 pins `1/2^n` (original). The proof needs non-negligible advantage; `1/2^n` is non-negligible. A `2^{-δn}` generalization would also work but is a v2 question.

---

## 6. Sources

- **Razborov & Rudich, *Natural Proofs*, JCSS 55(1):24–35, 1997** — the original.
- **Arora–Barak §23** — the definitional source; the reduction is here.
- **MIT 6.875 / Boaz Barak ch.4 (PRFs)** — the crypto primitive background (in `PRIOR_ART.md`).
- **The statement spec:** `docs/STATEMENTS/NaturalProofs.md`.
- **The constructivity debate** (Lance Fortnow 2024, "Natural Proofs is Not the Barrier You Think It Is") — argues constructivity is artificial. This is a *theoretical* critique; v1 keeps constructivity per the original (the proof needs it). Tracked, not folded in.
