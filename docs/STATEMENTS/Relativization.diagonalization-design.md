# Diagonalization design - BGS clause (b), sub-task 2 (#22)

**Status:** working-design note for `lean/PleaNP/Barriers/BGSDiagonal.lean`
(the proof of `exists_separating_oracle`, clause (b)). Written 2026-09-07
(run=20260907-2107-59bc) during the #22 claim. **NOT a frozen proof
spec and NOT a proof** - a decomposition plan that seeds the proof work,
per the sizing rule (one task = one agent run; tasks that can't fit get
decomposed further).

**Companion docs:** `docs/STATEMENTS/Relativization.md` (frozen informal
statement); `Relativization.proof-strategy.md` (§2 clause (b) sketch; §5
open proof-strategy questions); `docs/STATEMENTS/Relativization.lean.spec.md`
(rendering spec); `lean/PleaNP/Barriers/BGSDiagonal.lean` (U_B +
witness-core, #21 done).

---

## 1. What is already in place

- `BGSDiagonal.lean` (#21): `U_B : Oracle Query -> Set Nat` with
  `Query = Sigma n : Nat, Bits n`, `Bits n = Fin n -> Bool`; `IsWitness`;
  `U_B_iff_witness` (witness-core, zero sorry). Builds green.

- `Oracle.lean` (v4): `Oracle Q := Q -> Bool`, `Machine Q tm` with
  `queryLabel`/`yesLabel`/`noLabel`; `step` branches on the query label,
  consults the oracle, routes to yes/no labels; `evalsTo_unique_result`
  (deterministic halting endpoints agree). Builds green.



- `OracleComplexity.lean` (v4): `P_A`, `NP_A`, `AcceptsInTime`,
  `P_A_subset_NP_A` (both directions). Builds green.


## 2. The substrate wall that #22 inherits from #26/#27

`#26/#27` record a hard type-level contradiction for constructingthe
*membership* machine (`U_B in NP_A (alpha := Nat) B`): `NP_A` requires
`tm'.Gamma tm'.k0` to equal `Query = Sigma n : Nat, Bits n`, but `FinTM2`
bundles `[Gammak0Fin : Fintype ( Gamma k0)]` and `Fintype Query` is provably
uninhabitable (`Nat` injects via all-false length-tagged strings). See
`blockers/open_20260907-0953_bgs26-infinite-query-fintype.md`.

**#22 inherits the same wall.** The separating oracle `B` in the BGS stage
construction also lives over `Sigma n : Nat, Bits n` (a query about an n-bit
string tagged by length),and `P_A (alpha := Nat) B` quantifies a
machine with the same bundled-Fintype constraint - so any stage-machine
simulation/tournament against `B` hits the same `Fintype Query` wall. The
diagonalization cannot be completed against the *current* substrate as stated;
the resolution options ((a) finite reindexed query family, (b) substrate
generalization to infinite alphabets, (c) per-length reindexed class shape) in
#27 are the same options this task's shaft must await. This makes #22
**de facto blocked** on the same human decision - the "soft-blocked" note
in its body anticipated this.

**Recommendation to the queue:** #22 should be treated as
`status:blocked-needs-input` (or kept available only for the *design* work
below, which does not need the machine construction) until #27's human
decision lands. The design below is written so each option (a/b/c) can be
picked up without rework of the *combinatorial* core.


## 3. The proof shape (independent of the substrate choice)

The BGS clause-(b) strategy (per `Relativization.proof-strategy.md` §2):

> Build `B : Oracle Query` in stages `B_0 subseteq B_1 subseteq ...` so that for
> every deterministic poly-time oracle machine `M_i`, `M_i^B` fails to
> decide `U_B` on some input `1^n`: run `M_i` with "no" answers for
> fresh queries; if it accepts, leave B empty on length-n; if it
> rejects, add an unqueried n-bit string to B. Then `U_B in NP^B`
> (universal, #21) and `U_B notin P^B` (by the tournament),so `P^B != NP^B`.


### 3.1 Decomposition (each a one-run sub-task;gates per
`docs/MULTI_AGENT_WORKFLOW.md` §Gates:

| # | Sub-task | Lean obligation | Blocked by |
|---|---|---|---|
| D1 | **Counting lemma**: `exists n, p.eval n < 2^n` (per-stage `2^n >` queries) | new lemma in a `Combinatorics`/`Counting.lean` - the unqueried-string existence crux; Mathlib hooks below | None (pure Nat/Polynomial) |
| D2 | **Finite query family reindex** (per #27 option (a/(c)): `Bits (Fin N)` or per-length `Bits n` with bounded `N` | private bounded `Query`/`Bits` rework in `BGSDiagonal.lean` | #27 decision |
| D3 | **Machine enumeration**: poly-time oracle machines as Nats (`M_i <-> code`) | encoding of `FinTM2`+`Machine`; or reuse `Partrec.Code` if the tournament weakens to partial-recursive machines | substrate + #27 decision |
| D4 | **Stage construction**: `B : Nat -> Oracle Query` (monotone stages `B_k subseteq B_{k+1}}`;diagonalization at stage k not undone later | inductive def + monotonicity invariant | D2, D3 |
| D5 | **Tournament lemma**: forall code i, stage i gives `M_i^B(1^n) != U_B(1^n)` via the unqueried-string choice | combines D1, D4 | D1-D4 |
| D6 | **Assembly**: `U_B notin P^B`, then `exists B, P_A B != NP_A B` in `Relativization.lean` | composition + #23's job (sub-task 3) | D3-D5, #21 |

### 3.2 Mathlib hooks (verified present,u v4.31.0)

- **`2^n` growth:** `Nat.two_pow_*` family; `pow_lt_pow_right0`
  (`Algebra/Order/GroupWithZero/Basic.lean:568`)(`1 < a -> m < n -> a^m < a^n`);
  `Algebra/Order/Archimedean/Basic.lean:158`
`pow_unbounded_of_one_lt (x : R) (hy1 : 1 < y) : exists n, x < y^n` -
  the raw exists-n hook (works over any `ExistsAddOfLE` semiring;
  `Nat.choose_lt_two_pow` (`Data/Nat/Choose/Bounds.lean:91`) for
  binary-string counting.

- **Polynomial time bound:** `Polynomial ℕ` from
  `Mathlib.Algebra.Polynomial.Basic` (already imported by
  `OracleComplexity.lean`);`p.eval n` is Nat-valued.




- **Computable enumeration substrate:** `Nat.Partrec.Code` + `Denumerable Code`
  (`Computability/PartrecCode.lean:176`),`evaln` (bounded-step eval,
  `:568`),`evaln_complete`(`:690`),`primrec_evaln` (`:922`),
  and Rogers/Kleene fixed points (`:1004`,`:1022`) - the cleanest
  "enumerate programs + simulate for bounded steps" machinery Mathlib
  has. Gap: it enumerates *partial-recursive* codes, not *poly-time
  Oracle machines* - D3 must bridge (a `Computable`/`P`-detector,
  or a diagonalization that tolerates non-poly machines by punting slow
  ones to a filler input).
- **Determinism:** `evalsTo_unique_result` (Oracle.lean) - needed to
  know `M_i^B` has one behavior per input (tournament soundness).
- **BGS sandwich/PSPACE (clause (a):** not needed for (b):

## 4. What is missing (gaps to file as sub-tasks when the design is
approved)besides D1-D6:

- **Fintype Query decision** (#27): the blocking human choice that (a/b/c)
  picks the query family.(ALL of D2-D6 wait on it in the current
  substrate - though D1 is pure combinatorics and can start).
- **Machine encoding of FinTM2-oracle machines** (D3): no upstream
  instance; `Partrec.Code` is the closest reusable substrateand needs a
  reduction/bridge argument.

- **`#barrier_check` interplay:** any proof closing this must report the
  elaborator verdict per the gates discipline (expected: `#barrier_check`
  on the final `exists B, P_A B != NP_A B` in `Relativization.lean`: the
  statement itself carries no `Relativizing` instance -> **Inconclusive** -
  which is correct: BGS is the *meta*-theorem showing relativizing proofs
  can't resolve P vs NP, not itself a relativizing proof.). (Documented
  for #23's done-comment when it lands)

---

## 5. Recommendation scope for the next session

1. **D1 (counting lemma** can start immediately,u naffected by #27:
   prove `forall p : Polynomial Nat, exists n, p.eval n < 2^n` (or the per-stage
   `exists n, p.eval n < 2^n` bound)in a new `Combinatorics` module -
   pure Nat/Polynomial,no oracle substrate. Gate-evidence: build + hygiene.


2. **File #22's substrate blocker** afresh when the claim is swept: #22 inherits
   #27's human decision;the design above is written to route every option.

3. **After #27 lands:** execute D2-D6 in dependency order,one sub-task per run.