# Informal proof strategy: Algebrization (Aaronson–Wigderson)

**Rung:** 3c — informal proof-strategy outline for `docs/STATEMENTS/Algebrization.md`.
**Status:** **Informal strategy — NOT a frozen proof spec.** Preparatory doc, sourced to the literature. Explicitly *not* a Gate-1 frozen target. The frozen proof spec is written only after the algebrization statement is rendered against real types (oracle machines + low-degree extensions + finite fields) and Gates 1–5 pass. This doc informs without binding, and does not jump `LOCAL_AGENT_WORKFLOW.md` Step 6.

---

## 1. What this doc is and is not

- **Is:** an informal outline of how Aaronson–Wigderson 2009 is proved, so the eventual proof spec can be written fast against a known strategy.
- **Is not:** a frozen proof spec; a Lean rendering target; a substitute for `Algebrization.md` (the statement); or a Gate-1 artifact.

**Integrity constraint:** same as the other strategy docs — docs agent writes the informal strategy; frozen proof spec comes after statement freeze; proof search (Step 6) is gated. This doc sits before that gate, as preparation.

**v1 pin (per `Algebrization.md` §3):** this strategy targets the **AW09 multiquadratic** formulation. The ITCS 2026 multilinear-strengthening (`PRIOR_ART.md`, "Recent theoretical refinements") is a *separate* v2 strategy, not folded here.

---

## 2. The structure of the barrier (recap)

Per `Algebrization.md` §1, algebrization refines relativization by giving the simulating machine access not just to an oracle `A`, but to a **low-degree extension `Ã` of `A`** over a finite field. The barrier says: any algebrizing proof technique cannot resolve P vs NP, because there exist `(A, Ã)` pairs witnessing both sides (separation and equality) under the algebrizing access model.

Like relativization, the theorem is a **two-sided oracle existence result**, but the access model is *asymmetric*: the `NP` side gets `A`, the `P` simulator gets `Ã` (the extension). This asymmetry is the crux and the source of the formalization difficulty.

---

## 3. The proof strategy (sourced to Aaronson–Wigderson 2009, Theorem 3.17 and surrounding)

### The two clauses (per `Algebrization.md` §3)

- **Clause (a) — algebrizing separation:** `∃ A (recursive), ∃ Ã (low-degree extension of A), NP^A ⊄ P^Ã`.
- **Clause (b) — algebrizing equalization:** `∃ B (recursive), ∃ B̃ (low-degree extension of B), P^B = NP^B̃` (the exact form follows AW09 Theorem 3.17).

The barrier consequence: a proof that algebrizes (holds for every `A` and every low-degree extension `Ã`) cannot prove `P = NP` (contradicted by (a)) nor `P ≠ NP` (contradicted by (b)).

### The proof structure

The AW09 proof has three ingredients, each more intricate than its relativization analogue:

#### Ingredient 1 — the low-degree extension construction

For an oracle `A = {A_m}` with `A_m : {0,1}^m → {0,1}`, the **multiquadratic extension** `Ã` (v1 pin) over a finite field `F` (with `|F| > 2m`, so the extension is well-defined) is the unique multiquadratic polynomial `Ã_m : F^m → F` agreeing with `A_m` on `{0,1}^m`.

- **Construction:** standard polynomial interpolation — `Ã_m` is the polynomial that matches `A_m` on the Boolean cube and is multiquadratic (degree ≤ 1 in each variable). Existence and uniqueness follow from the field being large enough.
- **Why it matters for the barrier:** the `P` simulator gets access to `Ã`, which is *more* than `A` (it can query `Ã` at non-Boolean points). So `P^Ã` is *at least as powerful* as `P^A`. The barrier is about whether this extra power (the algebraic extension) is enough to collapse the gap.

#### Ingredient 2 — the separation oracle (clause (a))

AW09 construct an oracle `A` and its extension `Ã` such that `NP^A ⊄ P^Ã`. The strategy (analogous to BGS clause (b) but with the extension):

- The construction is a diagonalization against polynomial-time machines *with access to `Ã`* (not just `A`). The `NP^A` machine guesses + queries `A`; the `P^Ã` simulator queries `Ã`.
- The key technical lemma: querying `Ã` (the extension) at polynomially many points does *not* let the simulator determine `A`'s values at enough Boolean points to decide the diagonalizing language. This uses the **low-degree property**: a low-degree polynomial's values at a few non-Boolean points don't pin down its values at many Boolean points (the polynomial has too many degrees of freedom).
- The construction ensures the `NP^A` side can guess a witness that the `P^Ã` simulator can't find, because `Ã`-access doesn't reveal enough about `A`.

This is the **hardest part** to formalize: it's a diagonalization *with a low-degree-polynomial-hiding lemma*, where the hiding property is what makes the separation work.

#### Ingredient 3 — the equalization oracle (clause (b))

AW09 also construct `B` and `B̃` with `P^B = NP^B̃` (the equalizing side). The strategy (analogous to BGS clause (a), the QBF/PSPACE sandwich, but with the extension):

- Take `B` to be a PSPACE-complete language (like QBF), so `P^B = NP^B = PSPACE`.
- The extension `B̃` is its low-degree extension. The key: with `B` PSPACE-complete, a single query to `B` (or a small number to `B̃`) suffices for PSPACE computations, so the gap collapses.
- The asymmetry (`P^B` vs `NP^B̃`, not both on the same oracle) requires care: the equalization argument shows that `B̃`-access is rich enough that the `NP^B̃` side doesn't gain over `P^B`.

### The barrier corollary

As with relativization, the barrier statement is a corollary of (a) + (b): an algebrizing proof of `P = NP` would contradict (a); an algebrizing proof of `P ≠ NP` would contradict (b). The v1 target formalizes (a) and (b); the corollary is derived.

---

## 4. Formalization difficulty and dependencies (informal estimate)

| Element | Difficulty | Dependency |
|---|---|---|
| Oracle machines, `P^A`, `NP^A` | Shared with 3a | `Oracle.lean` v2 (recompose) |
| **Low-degree extension `Ã` over a finite field** | **Hard** — multiquadratic interpolation, uniqueness | Finite fields (Mathlib has these) + multiquadratic polynomial theory |
| The hiding lemma (low-degree → `Ã`-access doesn't reveal `A`) | **Very hard** — the crux technical lemma | The extension construction + polynomial degree arguments |
| Clause (a) separation diagonalization | Hard — diagonalization *against `Ã`-access machines* | The hiding lemma + machine enumeration |
| Clause (b) equalization (PSPACE sandwich with extension) | Moderate-Hard — needs PSPACE-completeness + the extension | PSPACE (shared with 3a clause (a)) + extension |
| The asymmetric access model (`NP^A` vs `P^Ã`) | Moderate — must be encoded precisely (the crux per `Algebrization.md` §3) | The complexity-class definitions with asymmetric oracle access |

**Honest read:** this is the **most technically intricate** of the three barriers to formalize (GAP_AUDIT §7 calls it this, and the proof strategy confirms why). It requires *everything* relativization needs (oracles, `P^A`/`NP^A`, machine enumeration) *plus* the low-degree-extension machinery over finite fields *plus* the hiding lemma. The hiding lemma — that low-degree polynomial values at few non-Boolean points don't determine values at many Boolean points — is a real polynomial-method argument and is the load-bearing technical content. This is why ROADMAP orders 3c *last* among the barriers: it depends on 3a's substrate *and* on finite-field polynomial theory.

---

## 5. Open proof-strategy questions (for the eventual frozen proof spec)

1. **The exact field `F` and its size.** AW09 require `|F|` large enough for the multiquadratic extension. The precise field choice is a Lean-author decision; the spec requires it be explicit (`Algebrization.md` §7). The hiding lemma's strength depends on the field size.
2. **The hiding lemma's exact statement.** "Low-degree polynomial values at `q` non-Boolean points don't determine values at `> q` Boolean points" — the precise form (and the polynomial-method proof) is the crux technical work. This is the single hardest lemma to formalize in the whole project.
3. **Composition with 3a.** Algebrization reuses `PleaNP.Oracles`; the local agent must verify the oracle types compose with the extension machinery (a Rung 2/3a design task per `Algebrization.md` §7).
4. **The multilinear (v2) strengthening.** Explicitly out of scope for v1; the ITCS 2026 result strengthens the multiquadratic barrier to multilinear extensions via the XOR-Missing-String problem. That's a *separate* future strategy doc, not folded here.

---

## 6. Sources

- **Aaronson & Wigderson, *Algebrization: A New Barrier in Complexity Theory*, ACM TOCT 1(1), 2009** (STOC '08; ECCC TR08-005) — the original; Theorem 3.17 and surrounding.
- **Arora–Barak §23** — the definitional source.
- **ITCS 2026** (*New Algebrization Barriers via Communication Complexity of Missing-String*) — the v2 strengthening; tracked, not folded in.
- **The statement spec:** `docs/STATEMENTS/Algebrization.md`.
- **The substrate specs:** `docs/STATEMENTS/Oracle.lean.spec.md` and `OracleTM2Recompose.spec.md` (shared with 3a).
