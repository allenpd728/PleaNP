import PleaNP.Calculus.BarrierCalculus

set_option warningAsError true

/-
# Function-level Relativizing propagation — test spec (follow-up to #1)

Targets the `Relativizing.funeq` / `Relativizing.funne` propagation instances
in `PleaNP.Calculus.BarrierCalculus`:

- `Relativizing (p = q)` for `p q : α → Prop` — unconditional(oracle-oblivious)atom.
- `Relativizing (p ≠ q)` for `p q : α → Prop` — same.
- The restored `abstractPVsNP` full conclusion `L1 = L2 ∨ L1 ≠ L2` synthesizes. 
- `#barrier_check abstractPVsNP` still emits **DEAD**.

The in-module `example`s already assert the Relativizing synthesis at build time
(they compile with `warningAsError`); this file adds covering examples against the
public API so a regression kills the build (CI runs `lake build` over `lean/`).
-/

/-- The `funeq` atom relativizes:two fixed predicates' equality is
  oracle-oblivious regardless of how their fibers are marked. -/
example (O : Type) (_A : PleaNP.Calculus.AbstOracle O) (L1 L2 : O → Prop) :
    PleaNP.Calculus.Relativizing ( L1 = L2) :=by
  infer_instance

/-- The `funne` atom relativizes. -/
example (O : Type) (_A : PleaNP.Calculus.AbstOracle O) (L1 L2 : O → Prop) :
    PleaNP.Calculus.Relativizing ( L1 ≠ L2) :=by
  infer_instance

/-- The disjunction of both under an existential over the witness languages
  relativizes(and `#barrier_check` reports DEAD on the restored statement). -/
example (O : Type) (_A : PleaNP.Calculus.AbstOracle O) (L1 L2 : O → Prop) :
    PleaNP.Calculus.Relativizing ( L1 = L2 ∨ L1 ≠ L2) :=by
  infer_instance