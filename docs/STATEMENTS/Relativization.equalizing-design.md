# Equalizing-oracle design — BGS clause (a), A1–A5 (#62)

**Status:** working-design note for the proof of `exists_equalizing_oracle`
(clause (a)) in `lean/PleaNP/Barriers/Relativization.lean`. Written 2026-09-12
(run=20260912-1258-8787) during the #62 claim. **NOT a frozen proof spec and
NOT a proof** — a decomposition plan that seeds the proof work, per the sizing
rule (one task = one agent run; tasks that can't fit get decomposed further).

**Companion docs:** `docs/STATEMENTS/Relativization.md` (frozen informal
statement, clause (a) §2); `Relativization.proof-strategy.md` (§2 clause (a)
sandwich; §5 open questions 1 — the PSPACE formalization question);
`docs/STATEMENTS/Relativization.lean.spec.md` (rendering spec, three traps);
`docs/STATEMENTS/OracleComplexity.lean.spec.md` (P^A/NP^A class spec);
`docs/STATEMENTS/Oracle.v5-repair.spec.md` (the word-query substrate this
design's machine constructions compile against; DEC-024, #35);
`lean/PleaNP/Barriers/Relativization.lean` (the `sorry` at line 80 this
closes); `docs/decisions/LOG.md` DEC-024.

---

## 1. What is already in place (the substrate the proof lands on)

- **`Oracle.lean` (v4, builds green, 0 sorries):** `Oracle Q := Q → Bool`
  (total by construction), `Cfg`/`Machine`, `step` (query branch consults the
  oracle and routes to yes/no labels), `evalsToUniqueResult` (deterministic
  halting endpoints agree), `DecidesInTime` (halts + output encodes χ_L),
  `step_none`, `outputEncodesChi`.

- **`OracleComplexity.lean` (v4, builds green, 0 sorries):** `P_A`/`NP_A` as
  `Set (Set α)` over `Oracle Q`, with `hΓ : tm'.Γ tm'.k₀ = Q` (v4 wiring),
  `AcceptsInTime (x,y)` (Flaw C fix), and `P_A_subset_NP_A` proved **both
  directions** via `evalsToUniqueResult`. **Note:** the v4 `hΓ` wiring forces
  `Fintype (tm'.Γ tm'.k₀)` — the `Fintype Q` wall for infinite query types.
  The v5 repair (DEC-024 / #35 / `Oracle.v5-repair.spec.md`) replaces that
  wiring with a dedicated query tape (`kq`), keeping `Oracle Q` untouched and
  **all frozen statements unchanged**. This design is written to compile
  against **either** substrate shape where possible; the machine constructions
  below state which shape they assume and what the v5 re-wire changes.

- **`Relativization.lean` (statement rendered, 2 sorries):** `QueryType :=
  List Bool`, `InputType := List Bool`, clause (a)
  `exists_equalizing_oracle : ∃ A, Computable A ∧ P_A A = NP_A A` (the
  `sorry` this design's A5 closes), clause (b) `exists_separating_oracle`.

- **`BGSDiagonal.lean` (#21):** `U_B` and the witness-core for clause (b)
  (zero-sorry). **Not** used by clause (a) — clause (a)'s witness is QBF, not a
  diagonalized B.

---

## 2. The proof shape (independent of substrate details)

The BGS clause-(a) strategy (per `Relativization.proof-strategy.md` §2):

> **Witness:** `A = QBF` (the set of true quantified Boolean formulas), or
> equivalently any PSPACE-complete language. **Sandwich:** show
> `P^A ⊆ NP^A ⊆ PSPACE ⊆ P^A`, closing `P^A = NP^A`. The middle inclusion
> (`NP^QBF ⊆ PSPACE`) uses that QBF is PSPACE-complete; the last
> (`PSPACE ⊆ P^QBF`) uses that a PSPACE computation reduces to one QBF query.

Concretely, the pieces (each in the A-table below):
- **A1** — decide the collapse construction: the **QBF oracle** (PSPACE-complete
  witness) vs the **EXP-complete witness** `A = { ⟨M, x, 1^m⟩ : M accepts x in
  2^m steps }`. Per `proof-strategy.md` §2 clause (a), QBF is "the cleaner
  variant" but requires a PSPACE/QBF substrate; the EXP-complete witness has a
  simpler decision procedure (bounded simulation) but requires an exponential
  time bound on machines. The design picks the construction after the A1
  statement-refinement pass.
- **A2** — define the **console oracle** `A : Oracle Q` for the chosen
  witness, and prove it is **total by construction** (`Oracle Q := Q → Bool`)
  and **computable** (`Computable A`).
- **A3** — the **content inclusion** `NP^A ⊆ P^A` (the non-trivial direction):
  a single oracle query to A decides any PSPACE computation in one step, so an
  `NP^A` machine (poly time with A-queries) is simulated by a `P^A` machine —
  the nondeterministic guessing is absorbed by the power of the QBF oracle.
- **A4** — the **trivial inclusion** `P^A ⊆ NP^A` (deterministic ⊆
  nondeterministic, relativized) — already proved on the substrate as
  `P_A_subset_NP_A` (both directions); this step reuses it for `A` and
  assembles the **sandwich** `P^A ⊆ NP^A ⊆ PSPACE ⊆ P^A`.
- **A5** — **assembly**: `P_A A = NP_A A` (extensional equality from both
  inclusions), then the full `exists_equalizing_oracle` with the `Computable`
  witness, closing SORRY_TRACKER #9, with gate evidence.

### 2.1 The two candidate witnesses (A1's decision)

| Candidate | Decision procedure | PSPACE/QBF substrate needed? | Notes |
|---|---|---|---|
| **QBF oracle** `A = QBF` | "is `φ` a true quantified Boolean formula?" | **Yes** — `PSPACE`/`QBF` definitions + PSPACE-completeness | "cleaner variant" per proof-strategy §2; requires the PSPACE substrate (not in mathlib; see §3.3). |
| **EXP-complete oracle** `A = { ⟨M, x, 1^m⟩ : M accepts x in 2^m steps }` | bounded-step simulation of `M` on `x` for `2^m` steps | **No** — uses the existing `FinTM2`/`Machine` step-counting substrate | A "console oracle" whose decider simulates the machine; the `P^A ⊆ NP^A ⊆ EXP ⊆ P^A` sandwich (EXP in place of PSPACE). |

**Design recommendation (A1 decides, pending the A2 machine construction):**
the **EXP-complete witness** is the lower-risk first target. It needs only the
existing oracle-machine step-counting substrate (`step`, `EvalsToInTime`,
`DecidesInTime` — all present in `Oracle.lean`), no new PSPACE/QBF
formalization. The QBF witness is the "textbook" cleaner sandwich but pulls in
a PSPACE-complete substrate that is not in mathlib (GAP_AUDIT §8) and is a
separate Rung-3b-sized effort. The design's A1–A5 sub-tasks are written so the
**QBF variant is a drop-in replacement** once a PSPACE substrate lands: the
console-oracle shape (A2), the inclusion machinery (A3–A4), and the assembly
(A5) are identical; only the witness's decision procedure differs.
`proof-strategy.md` §5 open-question 1 is answered here: PSPACE is not in
upstream mathlib, so the *initial* clause-(a) proof uses the EXP-complete
witness and the QBF version becomes an optional strengthening.

---

## 3. The A1–A5 decomposition (each a one-run sub-task; gates per
`docs/MULTI_AGENT_WORKFLOW.md` §Gates)

| # | Sub-task | Lean obligation | Mathlib / substrate hooks | Blocked by |
|---|---|---|---|---|
| **A1** | **Collapse-construction choice + statement refinement** | Refine `exists_equalizing_oracle`'s statement if needed (choose witness construction; confirm `Q = QueryType`, `Computable` hypothesis form, oracle totality). No new theorem — a statement-shape decision + doc. | `Relativization.lean.spec.md` §2 traps 1–3 (computability, equality encoding, query type) | none (design; may run parallel to the (b) path) |
| **A2** | **Console oracle definition + total-computability proof** | Define the witness `A : Oracle QueryType` (the EXP-complete or QBF oracle, per A1); prove `Computable A` (a decidable predicate over the query type). | `Oracle` totality-by-type (`Oracle Q := Q → Bool`); `Turing.Computable` from `Mathlib.Computability.TuringMachine.Computable` (already imported by `OracleComplexity.lean`) | A1 |
| **A3** | **`NP^A ⊆ P^A` inclusion machinery (the content direction)** | Prove: an `NP^A` verifier run is simulated by a `P^A` decider — a single query to the console oracle decides any *exponential*-bounded computation the verifier guesses. The bounding: certificate `y` bounded by `p.eval n`; the oracle decides the guessed witness check in one query. | `P_A`/`NP_A` definitions (`OracleComplexity.lean`); `DecidesInTime`/`AcceptsInTime` reachability; `P_A_subset_NP_A` as the reverse of the machinery if needed | A2, plus #35 (v5 word-query substrate — the machine construction needs the query-tape wiring; without it, the `Fintype Q` wall blocks the `QueryType = List Bool` machine's alphabet fusion) |
| **A4** | **`P^A ⊆ NP^A` (easy) + sandwich assembly** | Reuse `P_A_subset_NP_A` (proved on the substrate) for the oracle `A`; then compose `P^A ⊆ NP^A ⊆ P^A`-shaped sandwich (the two candidates differ in the middle: `EXP ⊆ P^A` for the console oracle vs `PSPACE ⊆ P^A` for QBF). | `P_A_subset_NP_A` (already landed both directions); set-extensional equality of `P_A A`/`NP_A A` (`Set (Set α)`) | A3 |
| **A5** | **Assembly + close the sorry** | `P_A A = NP_A A` by `Subset.antisymm` from A3+A4; then `exists_equalizing_oracle` with the `Computable A` witness; remove the `sorry` at `Relativization.lean:80`. Full gate evidence. | `Set.Subset.antisymm`; `Relativization.lean` statement (unchanged) | A3, A4 |

**Sub-task dependency order:** A1 → A2 → A3 → A4 → A5. A1 is design-only and
parallel-safe (no Lean). A2 is substrate-light (computability proof, no
machine construction) and can start as soon as A1 lands. A3–A5 need the
**v5 word-query substrate** (#35) for the machine constructions (see §4.1
below) — the design explicitly does NOT depend on upstream P/NP (DEC-003).

---

## 4. The substrate dependency: why A3–A5 sit on #35 (v5)

### 4.1 The v4 wall for the equalizing path

`P_A`/`NP_A` (v4) quantify a machine `tm'` with `hΓ : tm'.Γ tm'.k₀ = Q`.
`FinTM2` bundles `[Γk₀Fin : Fintype (Γ k₀)]` — the input alphabet is required
finite. For `Q = List Bool` (infinite), `Fintype Q` is uninhabitable (the
`Fintype Q` wall, `blockers/open_20260907-0953_bgs26-infinite-query-fintype.md`,
resolved by DEC-024). The **console-oracle machine** (A3's simulation) needs to
query the console oracle `A` — exactly the word-query path v5 provides (query
read from tape `kq`'s content over a finite alphabet, decoded to `Q`). So the
A3 machine construction waits on #35, exactly as the (b)-path D2–D6 do.

**This is not a blocker for the *design*:** A1–A2 are written against the
existing substrate; A2's `Computable A` proof uses only `Oracle`/`Turing`.
A3–A5 are written to compile against the **v5 shape** (`Machine` carrying a
`decode : List (tm'.Γ kq) → Q` field per `Oracle.v5-repair.spec.md` §2), with
the `hΓ`-wiring removed.

### 4.2 The `P^∅ = P` compatibility note (Trap 3 of the class spec)

Per `OracleComplexity.lean.spec.md` Trap 3 and `Oracle.v5-repair.spec.md` §4.2,
the empty-oracle class `P^∅` must equal upstream `P` (a Gate-2 model-consistency
statement, proof pending upstream P). For clause (a) this means: the **console
oracle is nonempty** (it answers QBF/EXP questions), so the A3 `P^A` machine
genuinely uses its oracle tape — no accidental dependence on the empty oracle
or on a `P^∅ = P` shortcut. The A3 simulation must be stated over the true
console oracle, not over the empty one.

---

## 5. Mathlib hooks (verified present at v4.31.0)

- **`Oracle` totality:** `Oracle Q := Q → Bool` (already in `Oracle.lean`) —
  totality is by type, no extra proof.
- **`Computable`:** `Turing.Computable` from
  `Mathlib.Computability.TuringMachine.Computable` (already imported by
  `OracleComplexity.lean`); `nat`-level `Computable` for the console-oracle
  decider via `Mathlib.Computability.Partrec`/`Partrec.Code` if the witness is
  phrased over ℕ-encodings.
- **Set-extensional equality:** `Set.Subset.antisymm` /
  `Subset.antisymm` (`Data/Set/Lattice`, `Mathlib.Data.Set.Basic`); the class
  equality `P_A A = NP_A A` is `Subset.antisymm` of two inclusions (Trap 2
  consistency — both are `Set (Set α)`).
- **Reachability/determinism:** `EvalsToInTime`, `evalsToUniqueResult`,
  `step_none` (all in `Oracle.lean`) — used by the A3 simulation's
  determinism arguments and the A4 reuse of `P_A_subset_NP_A`.
- **Bounded steps (EXP witness):** `2^m`-bounded simulation reuses
  `FinTM2`'s step-counting and `EvalsToInTime` (no new arithmetic substrate).
- **PSPACE/QBF (QBF variant, optional):** **not in mathlib core**
  (GAP_AUDIT §8). A PleaNP-local `PSPACE`/`QBF` substrate would be a separate
  ~Rung-3b-sized effort; the design's default is the EXP-complete witness to
  keep A1–A5 on the existing substrate. If/when a `QBF`/`PSPACE` substrate
  exists (upstream PR or local), A2's witness swaps to `QBF` and the sandwich
  A4 uses `PSPACE ⊆ P^A` instead of `EXP ⊆ P^A` — the A3/A4/A5 shapes are
  unchanged.

---

## 6. What is missing (gaps that #63's passes must resolve)

1. **The A3 simulation lemma** (the content direction): the exact Lean shape
   of "an `NP^A` verifier's poly-time run is absorbed by one console-oracle
   query". This is the hard lemma; it may decompose further (the verifier's
   certificate bound `p.eval n`, the single-query decision of the guessed
   witness, the reachability transfer). Resolved inside #63's Pass 2.
2. **The console-oracle decider** (A2): for the EXP witness, a
   `Partrec`/`Computable` decider for "`M` accepts `x` in `≤ 2^m` steps" —
   needs the machine-encoding substrate (same D3-style bridge the (b) path
   needs: encode `FinTM2` machines as codes for `Partrec.Code`/`Computable`).
   This is the one genuinely-new computability piece.
3. **`#barrier_check` interplay:** per the gates discipline, the closing
   `exists_equalizing_oracle` proof must report the elaborator verdict.
   Expected: **Inconclusive** — the statement itself carries no `Relativizing`
   instance, and correctly so: BGS clause (a) is the *meta*-theorem showing
   relativizing proofs can't resolve P vs NP, not itself a relativizing proof.

---

## 7. Recommendation scope for the first claim

1. **A1 (design decision)** can land immediately: pick the EXP-complete
   console oracle (the QBF variant documented as the drop-in strengthening),
   confirm the statement shape needs no change (`Relativization.lean` clause (a)
   is already rendered with `Computable`, total `Oracle`, set-extensional `=`).
2. **Do NOT file separate A1–A5 sub-issues** (confirmed during #62, mirroring
   the diagonalization precedent where D1–D6 remained passes of the
   implementation issue #22/#23 rather than separate issues): the existing
   implementation issue **#63** already consumes A2 (its Pass 1), A3 (Pass 2),
   and A4+A5 (Pass 3) as its three passes, and A1 is resolved by this design
   doc. Filing five more issues would duplicate #63's coverage and double-count
   the effort ledger. #63 is the claimable unit for the equalizing proof; this
   doc is its design reference.
3. **After #35 (v5) lands:** execute A3–A5 in dependency order via #63's
   passes, one pass per run; A5 closes SORRY_TRACKER #9.