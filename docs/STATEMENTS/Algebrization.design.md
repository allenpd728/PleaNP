# Algebrization design — AZ1–AZ6 proof-path decomposition (#68)

**Status:** working-design note for the Algebrization barrier
(Aaronson–Wigderson 2009, Rung 3c). Written 2026-09-13 (run=RUNID-68) during
the #68 claim. **NOT a frozen proof spec and NOT a proof** — a decomposition
plan that seeds the proof work, modeled on `NaturalProofs.design.md` (#67)
and `Relativization.diagonalization-design.md` (#22).

**Companion docs:** `docs/STATEMENTS/Algebrization.md` (frozen informal
statement — the Gate 1 anchor, AW09 multiquadratic v1 pin);
`Algebrization.proof-strategy.md` (informal strategy — §3 ingredients);
`docs/GAP_AUDIT.md` §7 (finite-field / Mathlib coverage);
`docs/UPSTREAM_TRACKING.md` §6.

---

## 1. What is already in place / pinned

- **Statement frozen** (informal, `Algebrization.md` §1/§3): the two-sided
  existential result under the algebrizing access model —
  `∃ A recursive, ∃ Ã low-degree ext of A, NP^A ⊄ P^Ã` (clause a,
  separation) and `∃ B recursive, ∃ B̃ low-degree ext of B, P^B = NP^B̃`
  (clause b, equalization), v1 = the **multiquadratic** extension.
- **Strategy written** (`Algebrization.proof-strategy.md` §3): three
  ingredients — (1) the low-degree extension construction (multiquadratic
  interpolation over `F`, `|F| > 2m`), (2) the separation diagonalization
  against `Ã`-access machines with a low-degree **hiding lemma**, (3) the
  equalization via a PSPACE-complete oracle + extension.
- **Scope/hard pins**: the asymmetric access model (`NP^A` vs `P^Ã` — the
  crux); the extension is a genuine low-degree extension distinct from `A`
  (Gate 2 collapse trap); both oracle and extension recursive (Gate 5);
  multilinear v2 (ITCS 2026) excluded from v1; namespace
  `PleaNP.Barriers.Algebrization`.

## 2. The substrate gap (algebraic side)

Algebrization needs everything relativization needs (oracles, `P^A`/`NP^A`,
machine enumeration — shared with Rung 3a and the v5 oracle substrate) *plus*
the finite-field + multiquadratic-polynomial machinery:

- **Finite fields**: Mathlib has them (`Mathlib.RingTheory`, `Mathlib.Field`)
  — present upstream.
- **Multiquadratic polynomials / the extension construction**: Mathlib has
  `Polynomial` (univariate) and some multivariate support, but the
  *multiquadratic-extension-of-an-oracle* construction (unique polynomial
  agreeing with `A : Bool^m -> Bool` on the Boolean cube, degree ≤ 1 per
  variable) is PleaNP-local — the interpolation/existence proof is real work.
- **The low-degree hiding lemma** (proof-strategy §3 ingredient 2): the single
  hardest lemma — "values of a low-degree polynomial at a few non-Boolean
  points don't pin down its values at many Boolean points". A polynomial-method
  argument; **no upstream equivalent exists**.

## 3. The proof shape (independent of the field choice)

**Clause (a).** Diagonalize against poly-time machines with `Ã`-access: build
`A`, `Ã` so that the `NP^A` side witnesses a language the `P^Ã` side cannot
decide; the hiding lemma stops `Ã`-queries from revealing `A`'s Boolean
values. **Clause (b).** Take `B` PSPACE-complete (QBF-style), `B̃` its
extension; `P^B = PSPACE` and `B̃`-access is rich enough that `NP^B̃`
collapses to the same set (AW09 Theorem 3.17 form).

### 3.1 Decomposition (each a one-run sub-task; gates per
`docs/MULTI_AGENT_WORKFLOW.md` §Gates; `#barrier_check` discipline per Rung 5)

| # | Sub-task | Lean obligation | Blocked by |
|---|---|---|---|
| **AZ1** | **Algebraic-oracle substrate decision**: the finite field `F` (size `> 2m`), the `BoolFunction m` / truth-table carrier, and the `MultiquadraticExt` construction (unique degree-≤1-per-variable extension agreeing on the Boolean cube) | a `MultiquadraticExt A` def with existence/uniqueness over `F`; Mathlib finite-field hooks (GAP_AUDIT §7) | Rung 3a substrate (oracles), finite-field imports |
| **AZ2** | **AW09 v1 statement rendered into Lean**: the two clauses with the *asymmetric* access (`NP^A` vs `P^Ã`), recursion on both oracle and extension, multiquadratic pinned | `lean/PleaNP/Barriers/Algebrization.lean` statement module (zero-sorry, Gate 1/4 read-back vs `Algebrization.md` §5) | AZ1, Rung 3a `P_A`/`NP_A` |
| **AZ3** | **Algebraic^P / Algebraic^NP class definitions**: the access model — `P^Ã` (simulator queries the extension) and `NP^A` (guesser queries the Boolean oracle) as distinct class operators | `AlgebraicP`/`AlgebraicNP` (or a single operator with the asymmetric args); Gate 2 (no collapse to relativization) | AZ2 (the statement), Rung 3a classes |
| **AZ4** | **The low-degree hiding lemma**: `Ã`-queries at `q` non-Boolean points don't determine `A`'s values at `> q` Boolean points | the polynomial-method lemma (the crux); Mathlib `Polynomial`/degree arithmetic | AZ1 (extension), field-size bound |
| **AZ5** | **Assembly of the barrier statement**: the separation diagonalization (clause a) + the equalization (clause b, PSPACE sandwich with extension) | the two existence theorems in `Algebrization.lean`; `#barrier_check` verdict expected Inconclusive (meta-theorem, not itself algebrizing) | AZ2–AZ4 (+ Rung 3a PSPACE for clause b) |
| **AZ6** | **Gates + read-back + comparator + file layout** (DEC-022): statement/proof module split, `#print axioms` standard-only, comparator/JSON `formalization.yaml` row | alignment rows + CI + read-back vs `Algebrization.md` §5 | AZ5 (the proved theorem) |

### 3.2 Mathlib hooks / prior-art (verified present, v4.31.0)

- **Finite fields:** `Mathlib.Field` / `Mathlib.RingTheory` — present; the
  field-size bound (`|F| > 2m`) uses `Fintype.card F` + `Nat` comparisons.
- **Boolean functions / truth tables:** `Bool`, `Fin m -> Bool` — as in
  Natural Proofs N1/Rung 4.
- **Polynomials:** `Polynomial` (univariate) and multivariate support in
  Mathlib; the multiquadratic extension needs a multivariate `Polynomial`
  family over `F^m` — verify the exact multivariate API (GAP_AUDIT §7 flag).
- **Oracle substrate:** `lean/PleaNP/Computability/Oracle.lean` /
  `OracleComplexity.lean` (v5, #35) — shared with Rung 3a; the extension is a
  new layer on top.
- **PSPACE (clause b):** shared with BGS clause (a) (`QBF`/PSPACE machinery,
  Rung 3a #18/#62) — the equalization sandwich uses the same PSPACE-complete
  oracle.

## 4. What is missing (gaps to file as sub-tasks when this design is approved)

- **The multiquadratic-extension construction** (AZ1) — the new PleaNP-local
  algebraic machinery; no upstream equivalent.
- **The hiding lemma** (AZ4) — the hardest lemma in the project; a real
  polynomial-method proof, not a bookkeeping task.
- **The exact field/F-size and clause-(b) form** — Lean-author decisions per
  `Algebrization.md` §7(1)(2), deferred to AZ1/AZ5.
- **File the AZ1–AZ6 sub-tasks** as separate issues with `Blocked by` this
  design (after approval) — same pattern as #62/#22/#67.

## 5. Recommendation / priority

1. **AZ1 (algebraic substrate) is the fork.** Everything keys off the
   finite-field multiquadratic-extension construction; it also needs the
   Rung 3a oracle substrate. Verify the multivariate-polynomial Mathlib API
   first (GAP_AUDIT §7).
2. **AZ2 (the v1 statement render) can proceed in parallel** once the oracle
   classes exist — the asymmetric-access statement shape is the Gate 1/4
   anchor and de-risks the whole path.
3. **AZ4 (hiding lemma) is the crux and should be scoped as its own careful
   task** — the polynomial-method argument is the load-bearing technical
   content; do not bundle it with assembly.
4. After AZ1–AZ4, execute AZ5 (assembly) -> AZ6 (gates/comparator), one
   sub-task per run.

---

_Last updated: 2026-09-13 (issue #68, design doc). The AZ-sub-task issues are a
follow-up once this design is approved._