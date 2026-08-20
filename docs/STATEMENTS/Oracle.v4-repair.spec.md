# Repair spec: `Oracle.lean` / `OracleComplexity.lean` v4 (reachability wiring)

**Status:** DRAFT repair spec (authoring track A, 2026-08-19). Not a frozen statement spec — this is a *repair work order* for the local agent, closing the gap between the v3 headers (which claim the flaws are fixed) and the v3 bodies (which are still vacuous). Reconcile with any track-B repair plan before execution.

**Scope:** `lean/PleaNP/Computability/Oracle.lean` and `lean/PleaNP/Computability/OracleComplexity.lean` only. Does not touch the barrier statements, the gates, or the rung ladder.

---

## 1. What v3 fixed and what it did not

| Flaw | v3 status | Evidence |
|---|---|---|
| **B — oracle inert** | **Fixed.** `step` branches on `queryLabel`, consults `Oracle.query`, routes to `yesLabel`/`noLabel`, pops the query. | `Oracle.lean` `step` body |
| **A — `DecidesInTime` vacuous** | **NOT fixed, but header claims it is.** Body is still `∀ x, ∃ cfg', cfg'.cfg.l = none ∧ outputEncodesChi …`; no `EvalsToInTime`, no `initCfg`; `ea`/`M`/`t` unused. | lethality scan: 3 `unused_param` violations |
| **C — `NP_A` vacuous certificate** | **Refactored, still vacuous.** New per-input `AcceptsInTime` is itself vacuous (`ea`/`M`/`xy`/`t` unused), and `NP_A` applies it to `x`, not `(x, y)`. | lethality scan: 4 `unused_param` + wrong input |
| **Bonus — duplicate binder** | `P_A_subset_NP_A` declares `(A : Oracle Q) (A : Oracle Q)` — does not typecheck. | `OracleComplexity.lean` |

**The process failure to prevent:** v3's module headers assert "ea, M, t are all load-bearing" while the bodies leave them unused. The repair is not done until the *body* (not the docstring) makes every parameter load-bearing — verified by the lethality scanner and the validation suite, not by the header text.

---

## 2. The one root cause

All remaining flaws are the same omission: **no reachability through the real step function.** Once `EvalsToInTime` is wired from the initial configuration through `PleaNP.Oracles.step`, the parameters become load-bearing by construction — `ea` builds the initial config, `M` provides the step function and oracle, `t` bounds the step count. Fix reachability once, in `DecidesInTime` and `AcceptsInTime`, and Flaws A and C both close.

---

## 3. The exact Mathlib API (verified against pinned v4.31.0)

The local agent does not need to design the reachability idiom — Mathlib already has it, and `TM2OutputsInTime` is the template:

```lean
-- StateTransition.lean:265  (the target relation)
structure EvalsToInTime {σ : Type*} (f : σ → Option σ) (a : σ) (b : Option σ) (m : ℕ)
    extends EvalsTo f a b where
  steps_le_m : steps ≤ m

-- Computable.lean:135  (the composition pattern to imitate)
def TM2OutputsInTime (tm : FinTM2) (l : List (tm.Γ tm.k₀)) (l' : Option (List (tm.Γ tm.k₁))) (m : ℕ) :=
  EvalsToInTime tm.step (initList tm l) ((Option.map (haltList tm)) l') m

-- Computable.lean:110  (initial config for a stack-loaded TM2)
def initList (tm : FinTM2) (s : List (tm.Γ tm.k₀)) : tm.Cfg
```

For PleaNP, `f := PleaNP.Oracles.step M`, `a := PleaNP.Oracles.initCfg M ea_input (ea x)`, `b := some cfg'`, `m := t (ea x).length`. The oracle-query branch of `step` is one application of `f`, so it counts as exactly 1 step — preserving the Trap-2 cost model.

---

## 4. Required changes

### 4.1 `Oracle.lean` — `DecidesInTime` (Flaw A)

Replace the vacuous body with real reachability:

```lean
def DecidesInTime {Q : Type} {tm : FinTM2} {alpha : Type}
    [DecidableEq tm.Λ] (ea : alpha → List (tm.Γ tm.k₀))
    (outputAlphabet : tm.Γ tm.k₁ → Bool)
    (M : Machine Q tm) (L : Set alpha) (t : Nat → Nat) : Prop :=
  ∀ x : alpha,
    ∃ cfg' : Cfg Q tm,
      EvalsToInTime (step M) (initCfg M (initList tm) (ea x)) (some cfg') (t (ea x).length) ∧
      cfg'.cfg.l = Option.none ∧
      outputEncodesChi outputAlphabet cfg' L x
```

Notes:
- `initCfg` currently takes an `ea : List … → tm.Cfg` parameter; pass `initList tm` (Mathlib's loader) so the initial config is the standard one. Adjust `initCfg`'s signature if the extra indirection is no longer needed.
- After this change `ea`, `M`, `t` all occur in the body — the lethality scanner's three `unused_param` violations must clear.

### 4.2 `OracleComplexity.lean` — `AcceptsInTime` (Flaw C, part 1)

Same reachability wiring, per-input, with a true-output acceptance condition:

```lean
def AcceptsInTime {Q : Type} {tm : FinTM2} {alpha : Type}
    [DecidableEq tm.Λ] (ea : alpha → List (tm.Γ tm.k₀))
    (oa : tm.Γ tm.k₁ → Bool)
    (M : Machine Q tm) (xy : alpha) (t : Nat → Nat) : Prop :=
  ∃ cfg' : Cfg Q tm,
    EvalsToInTime (step M) (initCfg M (initList tm) (ea xy)) (some cfg') (t (ea xy).length) ∧
    cfg'.cfg.l = Option.none ∧
    (match cfg'.cfg.stk tm.k₁ with
     | [] => False
     | head :: _ => oa head = true)
```

### 4.3 `OracleComplexity.lean` — `NP_A` (Flaw C, part 2)

Apply `AcceptsInTime` to the **pair `(x, y)`**, not to `x`:

```lean
      ∀ x : alpha,
        x ∈ L ↔ ∃ y : List alpha,
          y.length ≤ p.eval (ea (x, y)).length ∧   -- or keep the direct bound, but on the pair encoding
          @AcceptsInTime Q tm' (alpha × List alpha) h ea oa M (x, y) (fun n => p.eval n)
```

The certificate `y` must appear in the *acceptance* conjunct, not only the length bound. (Choose the length-bound convention — `ea (x, [])` vs `ea (x, y)` — and record it; the read-back must say "polynomial in the original input size.")

### 4.4 `OracleComplexity.lean` — duplicate binder (compile fix)

`P_A_subset_NP_A` has `(A : Oracle Q) (A : Oracle Q)`. Remove the duplicate.

### 4.5 `P_A` / `NP_A` — constrain the class oracle (from the v2 review, still open)

Both classes take `A : Oracle Q` but never require `M.oracle = A`. Add `M.oracle = A` to the existential, so the class's oracle is the machine's oracle. This is what makes `P_A A` actually *relative to A*.

---

## 5. Acceptance criteria (all must hold before claiming "fixed")

1. **Compiles** with zero `sorry` in the four changed definitions (the two `P_empty` theorems may keep their honest sorries — they track upstream P).
2. **Lethality scan clean of violations** on `lean/PleaNP`:
   `python3 tooling/gates/binder_usage_scan.py --allow-unreferenced '^(exists_equalizing_oracle|exists_separating_oracle)$' lean/PleaNP` → 0 violations. In particular, no `unused_param` on `ea`/`M`/`t` (`DecidesInTime`), `ea`/`M`/`xy`/`t` (`AcceptsInTime`), or `A` (`P_A`/`NP_A`).
3. **Header/body agreement.** The module headers must not claim a parameter is load-bearing unless the body uses it. Update the v3 "Fixed" claims to match reality.
4. **Validation suite (per `ValidationSuite.spec.md`):** at minimum, a `decide`-able **oracle-sensitivity smoke test** — one concrete machine, two oracles `A₁ ≠ A₂`, one input `x`, with `AcceptsInTime … A₁ … x` and `¬ AcceptsInTime … A₂ … x` both closed by `decide`. This is the executable proof that Flaw B stays fixed and the reachability wiring is real.
5. **`P_A_subset_NP_A` proved** (not sorry'd) once the class bodies are real — the structural tripwire. If it cannot be proved, the definitions are still wrong relative to each other.

---

## 6. What this repair does NOT do

- Does not prove BGS (clause a/b) — still blocked on PSPACE/QBF and the diagonalization.
- Does not define upstream P/NP — the `P_empty` sorries remain, tracking DEC-003.
- Does not wire the gates into CI — that is a separate reconciliation step, after the definitions validate.
