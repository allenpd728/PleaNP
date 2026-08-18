# Informal proof strategy: Relativization (Baker–Gill–Solovay)

**Rung:** 3a — informal proof-strategy outline for `docs/STATEMENTS/Relativization.md`.
**Status:** **Informal strategy — NOT a frozen proof spec.** This is a preparatory doc sourced to the literature, giving the *shape* of the proof work to come. It is explicitly *not* a Gate-1 frozen target. The frozen proof spec is written only *after* the relativization statement is rendered against real `P^A`/`NP^A` types (which wait on the `Oracle.lean` v2 recompose, DEC-010) and Gates 1–5 pass. Writing a binding proof spec before the substrate exists would jump `LOCAL_AGENT_WORKFLOW.md` Step 6 — this doc does not do that; it informs without binding.

---

## 1. What this doc is and is not

- **Is:** an informal, literature-sourced outline of how BGS 1975 is proved, so the eventual proof spec can be written fast against a known strategy. Useful for the local agent and the driver to understand the *shape* of the proof work.
- **Is not:** a frozen proof spec; a Lean rendering target; a substitute for the statement spec (`Relativization.md`); or a Gate-1 artifact. The statement spec is the source of truth for *what* is proven; this doc only sketches *how* one might prove it, informally.

**The integrity constraint, restated:** the same pipeline must not both formalize the statement and search for its proof (`FAILURE_AUDIT.md` Pattern A/C). This informal strategy is written by the docs agent; the eventual *frozen proof spec* must be written after the statement is frozen, and the *proof search* (Step 6) is a separate, gated stage. This doc sits *before* that gate, as preparation.

---

## 2. The two clauses and their proof strategies

The BGS theorem (per `Relativization.md` §1) has two existence clauses. Each has a distinct, well-known proof strategy from the literature. Both are *constructive* in the sense that they supply a specific oracle witness and a specific argument — they are not pure existence.

### Clause (a) — `∃ A (recursive), P^A = NP^A`

**Witness:** `A = QBF` (the set of true quantified Boolean formulas), or equivalently any PSPACE-complete language. The standard witness in the literature (e.g. the cs.wisc.edu / uva.nl lecture notes cited in `PRIOR_ART.md`; Arora–Barak §3) is `A = { ⟨M, x, 1^m⟩ : M accepts x in 2^m steps }`, which is EXP-complete; QBF (PSPACE-complete) is the cleaner variant.

**Strategy:** show `P^A = NP^A` by sandwiching both classes between two equal bounds:
- `P^A ⊆ NP^A` is the trivial direction (deterministic ⊆ nondeterministic, relativized) — true for any oracle, not specific to A.
- `NP^A ⊆ P^A` is the content. The key: a single oracle query to A (= QBF) can decide any PSPACE computation in one step. So an `NP^A` machine, which runs in polynomial time with QBF queries, can be simulated by a `P^A` machine: the nondeterministic guessing is absorbed by the power of the QBF oracle. Concretely, `NP^QBF ⊆ PSPACE ⊆ P^QBF` (a PSPACE computation can be encoded as a single QBF query), and `P^QBF ⊆ PSPACE` (each query is PSPACE-decidable). So `P^QBF = NP^QBF = PSPACE`.
- **The sandwich** `P^A ⊆ NP^A ⊆ PSPACE ⊆ P^A` closes the equality. The middle inclusion (`NP^A ⊆ PSPACE`) uses that QBF is PSPACE-complete; the last (`PSPACE ⊆ P^A`) uses that a PSPACE computation reduces to one QBF query.

**Why this is the *cleanest* barrier to formalize** (per GAP_AUDIT §4): it's an existence result about oracles with a concrete witness and a sandwich argument — no diagonalization, no deep property of proof techniques. The formal proof is "exhibit A = QBF, prove the three inclusions." The hard part is the substrate (`P^A`/`NP^A` definitions + QBF's PSPACE-completeness), not the proof logic.

### Clause (b) — `∃ B (recursive), P^B ≠ NP^B`

**Witness:** B is *constructed* by diagonalization — there is no fixed closed-form B; it's built in stages. This is the harder clause to formalize because the proof is an inductive construction, not a "exhibit and verify."

**Strategy (the standard diagonalization, sourced to Arora–Barak §3 and the lecture notes):**
- Define `U_B = { 1^n : ∃ x ∈ {0,1}^n, x ∈ B }` — the unary language "is there an n-bit string in B?". For *any* B, `U_B ∈ NP^B`: guess x (n bits), query B, accept iff B says yes. So `U_B ∈ NP^B` universally.
- Construct B in stages `B_0 ⊆ B_1 ⊆ ...` so that for every deterministic polynomial-time oracle machine `M_i`, `M_i^B` fails to decide `U_B` on some input `1^{n_i}`.
- **Stage i:** enumerate the i-th polynomial-time oracle machine `M_i` (with its polynomial time bound `p_i`). Pick `n` large enough that `2^n > p_i(n)` (more n-bit strings than M_i can query). Run `M_i^B(1^n)` for `p_i(n)` steps, answering "no" for any query to a string whose membership in B is not yet decided. Two cases:
  - If `M_i` accepts `1^n`: set B to have *no* n-bit strings (so the correct answer for `U_B(1^n)` is "no" — M_i was wrong to accept).
  - If `M_i` rejects `1^n`: pick an n-bit string y that `M_i` *didn't query* (exists because `2^n > p_i(n)`), and add y to B (so the correct answer is "yes" — M_i was wrong to reject). The unqueried-string existence is the crux: M_i can't have queried all `2^n` strings in polynomial time.
- After all stages, `B = ⋃ B_i`. For every `M_i`, `M_i^B(1^{n_i}) ≠ U_B(1^{n_i})`, so no `M_i^B` decides `U_B`. Thus `U_B ∉ P^B`, while `U_B ∈ NP^B`, giving `P^B ≠ NP^B`.
- **B is recursive** because the stage construction is an algorithm (enumerate machines, simulate for bounded steps, decide membership finitely) — this is why the spec's recursiveness hypothesis (`Relativization.md` §3) is satisfiable.

**Why this is the *harder* clause to formalize:** the proof is a stage-by-stage construction with a "pick an unqueried string" step requiring a counting argument (`2^n > p_i(n)`), an enumeration of polynomial-time oracle machines, and a consistency condition across stages (B is built monotonically; later stages don't undo earlier diagonalization). Each of these is a real Lean proof obligation. The formal proof will likely structure B's construction as an inductive/recursive definition with a proof of the diagonalization property at each stage.

---

## 3. The barrier *consequence* and how it's stated

The barrier statement ("relativizing proofs can't separate P from NP") is a *corollary* of (a) + (b), not a third theorem. The logic:
- Suppose a proof of `P = NP` relativizes (holds for every oracle). Then it holds for the B of clause (b), giving `P^B = NP^B` — contradicting (b).
- Suppose a proof of `P ≠ NP` relativizes. Then it holds for the A of clause (a), giving `P^A ≠ NP^A` — contradicting (a).
- So neither `P = NP` nor `P ≠ NP` has a relativizing proof.

The formalization choice (per `Relativization.md` §3): formalize clauses (a) and (b) as the two existence theorems. The *barrier consequence* can be stated as a corollary or left as the informal interpretation — the spec recommends formalizing (a) and (b) as the v1 target, with the consequence as a derived statement, since (a) and (b) are the load-bearing mathematical content.

---

## 4. Formalization difficulty and dependencies (informal estimate)

| Element | Difficulty | Dependency |
|---|---|---|
| Clause (a) witness (A = QBF) | Moderate — needs QBF's PSPACE-completeness | `P^A`/`NP^A` (recompose) + PSPACE formalization (likely upstream or PleaNP-local) |
| Clause (a) sandwich | Moderate — three inclusions, each standard | The substrate + PSPACE-completeness |
| Clause (b) `U_B ∈ NP^B` | Easy — universal, one guess + one query | `NP^A` definition |
| Clause (b) diagonalization construction | **Hard** — stage construction, counting, machine enumeration, monotonicity | `P^A` definition + enumeration of poly-time oracle machines + the `2^n > p_i(n)` counting lemma |
| Clause (b) "B is recursive" | Moderate — the construction is computable | The construction as a computable function |
| Barrier corollary | Easy once (a)+(b) exist | (a) and (b) |

**Honest read:** clause (a) is the "cleanest target" GAP_AUDIT names, and it's genuinely cleaner — a sandwich argument with a fixed witness. Clause (b) is the real formalization work: an inductive construction with a counting argument. The relativization *proof* will likely be 70% clause (b) by effort. This is consistent with ROADMAP Rung 3 being scoped as "the real work, multi-year."

---

## 5. Open proof-strategy questions (for the eventual frozen proof spec, not now)

These are *not* for immediate resolution — they're to flag what the eventual proof spec will need to decide, once the substrate exists:

1. **PSPACE formalization.** Clause (a) needs QBF to be PSPACE-complete and `PSPACE` to be definable. Is PSPACE in upstream Mathlib or PleaNP-local? (GAP_AUDIT §8: not present; likely PleaNP-local or tracked upstream.) This may make clause (a) *less* unblocked than it appears — the sandwich needs PSPACE.
2. **Enumeration of polynomial-time oracle machines.** Clause (b) needs to enumerate `M_1, M_2, ...` — all deterministic poly-time oracle machines. This is a computability-theoretic construction (encoding machines as strings, enumerating). Mathlib has computability infrastructure, but "polynomial-time oracle machines" as an enumerable set is substrate work.
3. **The `2^n > p_i(n)` counting lemma.** Standard but needs formalizing: for any polynomial `p_i`, `∃ n, 2^n > p_i(n)`. Easy lemma, but it's a proof obligation.
4. **Monotonicity of the B construction.** B is built as `⋃ B_i` with `B_i ⊆ B_{i+1}`; the diagonalization at stage i must not be invalidated by later stages. This is an invariant the formal construction must maintain and prove.

---

## 6. Sources

- **Baker, Gill, Solovay (1975)** — the original construction.
- **Arora–Barak §3** — the definitional source (per `UPSTREAM_TRACKING.md` §6); the sandwich (a) and diagonalization (b) are both here.
- **Lecture-note constructions** (in `docs/PRIOR_ART.md` search): Jin-Yi Cai CS 810 Lecture 8 (cs.wisc.edu); Ronald de Haan Complexity Lecture 5 (uva.nl); IISc Bangalore lec9.
- **The statement spec:** `docs/STATEMENTS/Relativization.md` — the frozen informal statement this strategy proves.
- **The substrate spec:** `docs/STATEMENTS/OracleTM2Recompose.spec.md` — the recompose that unblocks `P^A`/`NP^A`, which the proof waits on.
