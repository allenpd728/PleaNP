# Repair spec: `Oracle.lean` / `OracleComplexity.lean` v5 (word-query substrate)

**Rung:** 2 (local piece. **Status:** Work-order spec (DEC-024, 2026-09-11, run=20260911-0944-qmzn) — the direction chosen by the Option Ω creative-protocol run;implementation is #35.. **Supersedes:** the v4 `hΓ : tm'.Γ tm'.k₀ = Q` wiring (the Fintype-Query wall;;the v4-repair spec's ( §4.1–4.4) stays valid except where overridden here. **Read first:** `docs/STATEMENTS/Oracle.lean.spec.md` §2.2 (the "oracle tape" model this restores;;`docs/STATEMENTS/OracleTM2Recompose.spec.md` §4 (the three traps;;`blockers/open_20260907-0953_bgs26-infinite-query-fintype.md` (the wall this fixes;`docs/decisions/LOG.md` DEC-024 (the decision record.

---

## 1. The one root case (what v4 did wrong)

v4 fused the **query type** into the **input-tape alphabet slot**:`P_A`/`NP_A` quantify a machine `tm' : FinTM2` with the constraint `hΓ : tm'.Γ tm'.k₀ = Q` — i.e. `` the input tape's alphabet must *be* the queryspace. But Mathlib's `FinTM2` bundles `[Γk₀Fin : Fintype (Γ k₀)]` (the input alphabet is REQUIRED finite),and for `Q = Σ n, Bits n` (infinite),`Fintype Q` is provably uninhabitable (`Nat` injects via all-false length-tagged strings;;verified in Lean v4.31.0). So the query type is asked to be *both* an infinite value-space *and* a finite alphabet — a type-level contradiction.

The repo's own spec (`Oracle.lean.spec.md` §2.2) never asked for this:it says the oracle machine has a dedicated **oracle tape**,and "the string currently on the oracle tape is treated as a query q". A *word on a tape* over a finite alphabet is infinite-valued but alphabet-finite — the standard reconciliation. v4 implemented the shortcut (reuse input-tape-head-as-query,,which forced the alphabet fusion;;v5 removes that shortcut.



## 2. The v5 substrate shape (the target after this spec is implemented)

- **`Oracle` stays exactly as-is:** `Oracle Q := Q → Bool` (total, codomain `Bool`.. *Do not touch.**
- **`Q` stays exactly as-is:** for BGS,`Q = Σ n : Nat, Bits n`, `Bits n = Fin n → Bool` — `lean/PleaNP/Barriers/BGSDiagonal.lean:45-49` unchanged. *Do not touch the frozen statement files at all.**
- **The query tape:** FinTM2 is multi-tape (`Γ : Fin → Type` · a function from tape-index to alphabet-typed).v5 introduces a **dedicated query-tape index** `kq : Fin (tm.Γ.length)` (a new peer of `k₀` and `k₁`).During a query transition, the *content of tape `kq`* (a `List (tm.Γ kq)`,finite-length word over the finite alphabet `Γ kq`] is consumed as the query;,not the input-tape head.
- **The decode function:** the word on the query tape is decoded to a value of the oracle's query type:```lean
decode : List (tm.Γ (tm.kq) → Q
```
  (in `P_A`/`NP_A` this amounts to a function chosen per machine,and a proof obligation that the decode is *total* and *surjective-enough*:every oracle query a machine might need is expressible by some word — for BGS,`Q = Σ n, Bits n`andthe word is the n-bit guess string itself(see §3.1). *Totality of the oracle itself is untouched* — the Oracle type is still total;decoding may be partial-per-encoding,but that lives in the machine-witness,not in the oracle. （The totality discipline of `Oracle.lean.spec.md` §3 applies to `Oracle Q`,not to `decode`.）
- **The query transition (one step, preserved):** when the current label is `queryLabel`,ther machine consumes the query-tape word (exactly one `step` application),consults `Oracle A` once on the decoded value,and routes to `yesLabel`/`noLabel`. The *consultation* stays exactly 1 step in `EvalsToInTime` —same as v4. Writing/the-query-word earlier is *ordinary* multi-tape work (counted normally,polynomial — fine.. **No simulation of A's decider;no amortization;no 0-step queries.** (Per `OracleTM2Recompose.spec.md` §4 trap 2.)

- **`P_A` / `NP_A` re-typing (the only class-level change):** the `hΓ : tm'.Γ tm'.k₀ = Q` constraint **disappears**;replaced by a query-alphabet-agnostic wiring:
  - `P_A`:```lean
def P_A {Q alpha : Type} (A : Oracle Q) : Set (Set alpha) :=
  { L | ∃ (tm' : FinTM2) (kq : Fin tm'.Γ.length) (hΓkq : tm'.Γ kq = ...)  -- if a separate index type is needed
       (h : DecidableEq tm'.Λ) (ea : alpha → List (tm'.Γ tm'.k₀)
       (writeQ : alpha → List (tm'.Γ (tm'.kq))  -- the word the machine writes to tapekq per input
       (decode : List (tm'.Γ (tm'.kq) → Q) (oa : tm'.Γ tm'.k₁ → Bool)
       (M : @Machine (tm'.Γ (tm'.kq) tm' h) (p : Polynomial ℕ),
      M.oracle = A ∧
      (@DecidesInTime tm' alpha h (fun x => ea x ++ writeQ x) oa
         { M with oracle := A  -- or keep M construction as-is via helper
       L (fun n => p.eval n) }
```
  — *the local agent picks the cleanest concrete rendering* (e.g. `Machine` parameterized by the query *value* type `Q` straightforwardly,with the step function reading tape `kq` and decoding;;the sketched signature above is the *shape*,not a gospel copy..The invariants that matter are listed §4..
  - `NP_A`: same re-typing,and `AcceptsInTime` applied to `(x, y)` stays (Flaw C fix kept;;the certificate `y` bounds via `p.eval`,unchanged.
  - **`M.oracle = A`** (or `= h.symm ▸ A` as v4 did,depending on how `Machine Q` is parameterized):the oracle is now tied to the machine by **type** （`Machine`'s `Q` field),not by the input-alphabet equality.. Keep the totality discipline (`Oracle Q`,not `RecursiveIn`）.



##  ̄3. The BGS-facing acceptance details (why the fix keeps everything frozen

### 3.1 The U_B-query path (what #36's machine will do)

- Input:`1^n` ↦ alpha = `Nat`;;the machine's *ordinary input* is n (theunary length।;the tape `k₀` holds n's encoding.
- The guessed witness `x : Bits n` is written,bit-by-bit,onto tape `kq` —a word of length n over `Γ kq` (which must have at least a two-symbol alphabet, e.g. the base `Fin 2` —the local agent confirms a `FinTM2` instance or a private `Fin 2`-alphabet machine exists in the substrate.
- The decode function maps that n-symbol word to `⟨n, x⟩ : Q` — length-tagged,exactly `U_B`'s query shape. *Every* `x : Bits n` must be encodable (surjectivity onto the n-fiber of Q,:the all-false assignment is just `x ≡ false`) —so the BGS "2^n strings" counting is *faithful*:the query-word space per length n has exactly 2^n words,,one per x.. （This is the point where the old (a)-option "bounded query family" would have *broken* BGS faithfulness —capping n;;v5 keeps all lengths.）
- Cost: writing the word = n steps (counted normally;fine,polynomial.;the consultation = exactly 1 step..

### 3.2 The diagonalization-facing requirement (#37's tournament

- Every poly-time oracle machine `M_i` in the enumeration queries via the *same* `decode` convention — so the tournament's "unqueried string" argument needs the counting `2^n > p_i(n)` over the *query-word space*,which is exactly the n-fiber of Q (size 2^n). The v5 substrate gives **no machine power to query anything but length-tagged bitstrings wel（via `decode`,);so `U_B` andthe diagonalization live over the *same* query space — no drift..



##  ̄4. Required changes (checklist for #35's implementation

###​ 4.1 `Oracle.lean` — introduce the query tape and word-query step

1. Add a constant or index for the query tape:```lean
def kq := 2  -- or a dedicated Fin index; the local agent pins the multi-tape convention (which index is input/query/output and how FinTM2 numbers them
```
 (If the existing `k₀`/`k₁` are fixed indices,add a third— or reusean existing tape if the FinTM2 model exposes one via a different slot. *The spec requires a *distinct, dedicated* tape,not the input tape*.
2. Rewire `step`:in the query branch,read `c.cfg.stk (tm.kq)` (the full word),decode via a machine-carried `decode` function(or a `Vary` on `Machine`),consult `Oracle A` once on the decoded value,routes yes/no;clear/consume the query-tape content per the tape-model convention（ the local agent pins:does the next query overwrite from position 0?（ yes — the write function writes a fresh word each time;the step consumes it entirely in one consultation.）.
3. `Machine`'s type parameter:```lean
structure Machine (Q : Type) (tm : FinTM2) [DecidableEq tm.Λ] where
  oracle : Oracle Q
  decode : List (tm.Γ (Oracle.kq tm) → Q  -- this field is NEW
  queryLabel : tm.Λ
  yesLabel : tm.Λ
  noLabel :tm.Λ
```
 (If FinTM2's tape-index type makes referencing `tm.kq` awkward,a local `abbrev QueryTape (tm : FinTM2) := ...` helps;the exact field-bearing shape is the local agent's call** — *the load-bearing invariants are §4.3*..
4. Keep `initCfg`,`step_none`,`outputEncodesChi`,`DecidesInTime` semantics (the latter's `ea` now builds *both* input and query-tape initial content —or a `writeQ` conjunct,per §2's signature-shape;the local agent picks the composition that compiles..

###​ 4.2 `OracleComplexity.lean` — re-type `P_A` / `NP_A` data

1. Delete the `hΓ : tm'.Γ tm'.k₀ = Q` bindersin `P_A` and `NP_A`;
2. Add the machine-side witness data for the query channel (decode + word-writer，per §2's shape;
3. Keep `AcceptsInTime` applied to `(x,y)` (Flaw C fix ;;keep `P_A ⊆ NP_A` theorem (re-prove under the new shape via the same determinism argument;`evalsTo_unique_result` is untouched..
4. `P^∅ = P` compatibility (Trap 3,:state as:with the empty oracle `A := fun _ => false`,the classes reduce to no-oracle poly-time TM2 machines —the query tape simply stays empty/never queried. Re-render the statement-only compatibility anchor if the old one (`OracleUpstreamP.lean`) referenced the v4 hΓ-shape.) .

###​ 4.3 The invariants (gate checklist — these are what "fixed" means

1. **Totality:** `Oracle Q := Q → Bool`,codomain `Bool` — cosmetically untouched;scan/read-back must confirm.
2. **Query = exactly 1 step:** the query transition appears in `tm.step` as one application,and `EvalsToInTime` counts it as one step (no simulation,no 0-cost,no amortization;an explicit note/example in the module per `OracleTM2Recompose.spec.md` §4 trap 2..
3. **No `Fintype`-on-query:** no `hΓ`-style equality forcing the query value-space into a `Fintype` slot;the query tape's *alphabet*`Γ kq` stays finite (that's a real physical constraint,unweakened);the query *value-space* `Q` stays arbitrary (infinite for BGS\x80.
4. **Frozen statements untouched:** `BGSDiagonal.lean` (`Query`,`Bits`,`U_B`,`IsWitness`,`U_B_iff_witness`),`Relativization.lean` — *zero edits*;the spec/read-back's Gate-4 statements unchanged..
5. **Surjective-enough decode:** for BGS,the decode maps n-symbol words bijectively onto the n-fiber of Q（ so 2^n query-words per length;;filed as a comment/proof-obligation note in `OracleComplexity.lean`,not necessarily a separate lemma —the machine construction (#36) will need it.
6.. **`P_A ⊆ NP_A` still holds** (re-proved;the structural self-check is the v4 repair's behavioral witness)..
7.. **`P^∅ = P`(empty oracle) compatibility re-stated** (per §4.2④ — statement-level,proof may wait on upstream P,per `OracleUpstreamP.lean`'s existing sorry-tracking;the *statement* must not regress.

.



##  ̄5. Acceptance criteria (all must hold before claiming #35 "done"

1. `lake build PleaNP.Computability.Oracle PleaNP.Computability.OracleComplexity PleaNP.Computability.OracleSmoke` green (v4.31.0 / Mathlib v4.31.0;
2. Gate scans on the three modules:```bash
python3 tooling/gates/hygiene_scan.py --prove-stage lean/PleaNP/Computability/Oracle.lean lean/PleaNP/Computability/OracleComplexity.lean
python3 tooling/gates/vacuity_scan.py lean/PleaNP/Computability/Oracle.lean lean/PleaNP/Computability/OracleComplexity.lean
python3 tooling/gates/binder_usage_scan.py --allow-unreferenced '^(exists_equalizing_oracle|exists_separating_oracle|smoke_accepts_true|smoke_rejects_false)$' lean/PleaNP
```
  (zero violations;every new binder —`decode`,`writeQ`,`kq` — must be load-bearing in the body,not docstring..
3.. `OracleSmoke.lean` updated:the smoke machine now writes a query *word* onto tapekq (e.g. `1 0 1`),queries once,accepts/rejects per the two oracles —the executable check that the word-query path works end-to-end (and that the answer routes to yes/no labels correctly;.
4.. An explicit `example`/note pinning the 1-step property of the query transition (per §4.3②..
5.. `P_A ⊆ NP_A` re-proved both directions;`P^∅ = P` compatibility re-stated(rn `OracleUpstreamP.lean` if that module's statement referenced the v4 shape
6.. Read-back sanity:the class definitions' plain-English reading must still match `docs/STATEMENTS/OracleComplexity.lean.spec.md` (P^A = languages decidable by a deterministic oracle machine with *one-step* queries,etc..



##​ 6. What this repair does NOT do

- **Do NOT** define `P`/`NP` locally(`Complexity.*` namespace contested —DEC-002;;PleaNP classes stay `PleaNP.Oracles.*` and compose with upstream when it lands,per DEC-003/`UPSTREAM_TRACKING.md`.
- **Do NOT** touch the frozen barrier statements (`BGSDiagonal.lean`,`Relativization.lean` — zero edits,per Gate-1/4 discipline;that's the whole point of Ω)...
- **Do NOT** weaken `Fintype (Γ k₀)` or any bundled finiteness on *alphabets*(alphabets stay finite;;only the *query value-space*`Q` is decoupled from alphabets.
- **Do NOT** re-define the oracle (totality discipline unchanged;;no `RecursiveIn`/`TuringReducible` reuse,per `Oracle.lean.spec.md` §3...
- **Do NOT** change the cost model (writing ordinary steps,consultation = 1 step;no amortization/no simulation,per §4.3

---

##​ 7. Follow-ups fed by this repair (dependency map

| Issue | Consumes | Gate evidence needed there |
|---|---|---|---|
| #36 (U_B-in-NP write the word-query machine | #35 (**implementation of THIS spec** | build green + hygiene + `#barrier_check` verdict noted |
| #37 (diagonalization D1–D6 | #35,#36 | D3 enumeration + D5 counting over the query-word space |
| #38 (campaign re-scope | #35 | lens B's machine-construction needs the repaired substrate |
| #40 (Tests: v5 repair | #35 | test spec per §5③-⑤ |