import PleaNP.Circuits.Basic
import PleaNP.Calculus.Soundness
import PleaNP.Computability.Oracle

set_option warningAsError true

/-!
# AC⁰ lower bound milestone — parity ∉ AC⁰ (issue #72, Pass 1)

Rung 4's marker circuit lower bound, on the `PleaNP.Circuits` substrate
(issue #71, `d6857d9`: `BoolGate` with structural `size`/`depth`,
`BoolFunc`, `CircuitFamily`).

Pass 1 (this module) — the **statement layer + structural content**, all
zero-sorry:

- `BoolGate.eval`: the missing circuit **semantics** (evaluation of a gate
  term on an assignment), the load-bearing bridge between the `BoolGate`
  syntax and the Boolean function it computes.
- `parity n`: the parity function (XOR of all `n` inputs).
- `IsAC0 C`: a constant-depth circuit family (`∃ d, ∀ n, depth (C n) ≤ d`).
- `ComputesParity C`: the family agrees with parity at every length.
- `parity_notin_AC0`: the frozen lower-bound statement — no constant-depth
  family computes parity. **Not yet a theorem** (the switching-lemma
  depth-reduction is Pass 2); rendered as a zero-sorry `def` target.
- Structural meaningfulness lemmas (so the statement is not vacuous):
  `parity_zero`, `parity_single_true`, `parity_single_false`,
  `parity_nontrivial` — parity is a genuine, non-constant family.

**Barrier classification (for Rung 4):** the parity ∉ AC⁰ lower bound is
**relativizing** (it holds relative to every oracle — the proof never uses
oracle access) and **natural** (it is exactly Razborov–Rudich's canonical
example: a large, constructive property that would break OWFs). It does not
separate P from NP. Classification link: `docs/ROADMAP.md` Rung 4 + the
#73 issue (barrier classifications).

Pass 2: the switching lemma (random-restriction depth reduction) — the
actual hardness proof. Tracked in #72's follow-up.
-/

namespace PleaNP

namespace Circuits

/-- **Evaluation of a Boolean circuit on an assignment.** The semantics of
  `BoolGate`: an input gate reads its variable, AND/OR/NOT gates apply the
  Boolean operation. This is the bridge asserting a gate term actually
  computes the function we claim. -/
def BoolGate.eval {n : Nat} : BoolGate n → (Fin n → Bool) → Bool
  | .input i, v => v i
  | .and a b, v => BoolGate.eval a v && BoolGate.eval b v
  | .or a b, v => BoolGate.eval a v || BoolGate.eval b v
  | .not a, v => !(BoolGate.eval a v)

/-- The **parity** Boolean function on `n` inputs: the XOR of all bits.
  Parity is the canonical function separating AC⁰ from polynomial-size
  unbounded-depth circuits (it is in polynomial size but not constant depth). -/
def parity (n : Nat) (v : Fin n → Bool) : Bool :=
  (List.ofFn v).foldr (fun b acc => xor b acc) false

/-- A circuit **family** has constant depth — the AC⁰ shape. -/
def IsAC0 (C : CircuitFamily) : Prop :=
  ∃ d : Nat, ∀ n : Nat, BoolGate.depth (C n) ≤ d

/-- A family **computes parity** if its eval agrees with parity at every length. -/
def ComputesParity (C : CircuitFamily) : Prop :=
  ∀ n : Nat, ∀ v : Fin n → Bool, BoolGate.eval (C n) v = parity n v

/-- **The frozen lower-bound statement (Pass 2's theorem):** no
  constant-depth circuit family computes parity. Rendered here as a
  zero-sorry `def` target; the switching-lemma proof is Pass 2. -/
def parity_notin_AC0 : Prop :=
  ¬ ∃ C : CircuitFamily, IsAC0 C ∧ ComputesParity C

/-- Parity of the all-false assignment is `false`. -/
lemma parity_zero (n : Nat) : parity n (fun _ => false) = false := by
  unfold parity
  rw [List.ofFn_const]
  induction n with
  | zero => decide
  | succ m ih =>
      simpa [List.replicate, xor] using ih

/-- Parity of the single-`true` word at length 1 is `true`. -/
lemma parity_single_true : parity 1 (fun i => i = 0) = true := by
  decide

/-- Parity of the all-false word at length 1 is `false`. -/
lemma parity_single_false : parity 1 (fun _ => false) = false := by
  unfold parity
  simp

/-- Parity is genuinely non-trivial: it takes both Boolean values at
  length 1, so `parity` is not a constant family (the statement `parity ∉
  AC⁰` is about a real function, not a name). -/
lemma parity_nontrivial :
    (∃ v : Fin 1 → Bool, parity 1 v = true) ∧ (∃ v : Fin 1 → Bool, parity 1 v = false) := by
  constructor
  · exact ⟨fun i => i = 0, parity_single_true⟩
  · exact ⟨fun _ => false, parity_single_false⟩

/-- The substrate's `and2` gate evaluates to the AND of its inputs on a
  concrete assignment (sanity: the new `eval` agrees with the intended
  semantics; `and2` from `Circuits.Basic`). -/
example :
    BoolGate.eval and2 (fun _ : Fin 2 => true) = true := by
  decide

/-! ## Barrier classification — AC⁰/parity is relativizing (issue #73 Pass 2)

The first per-family classification using the Rung-4 method (#73 Pass 1,
`Classification.lean`): the AC⁰ lower-bound claim `parity_notin_AC0` is
**oracle-uniform** (relativizing) — the statement and its (eventual)
switching-lemma proof never consult an oracle, so its truth is invariant
under *any* oracle replacement. Formally: the family-indexed claim
`fun _ : Oracle Q => parity_notin_AC0` satisfies `UniformInOracle` (it is
the constant family, trivially uniform). An AC⁰ proof therefore cannot
separate P from NP (BGS blocks it) — it is a *relativizing* technique.

Also natural (per RR's canonical example): the circuit/large-property
classification is recorded in the module header; the algebrizing check is
a separate row (#73 Pass 3).
-/

/-- **AC⁰/parity relativizes**: the AC⁰ lower-bound claim, viewed as a
  family over any oracle, is oracle-uniform — the constant family
  `fun _ => parity_notin_AC0` is `UniformInOracle` by vacuity (no oracle
  appears). This is the Rung-4 classification method (spine) applied to
  the first lower bound: `parity_notin_AC0` cannot be a P-vs-NP
  resolution because it is relativizing. -/
theorem parity_notin_AC0_relativizing (Q : Type) :
    PleaNP.Calculus.UniformInOracle Q (fun _ : PleaNP.Oracles.Oracle Q => parity_notin_AC0) := by
  intro _ _ _
  rfl

/-! ## AC0 lower-bound structural core — depth-0 structure (issue #72 Pass 2)

The structural pretext of the switching-lemma depth-reduction: a **depth-0
circuit** is a single input gate (it reads one variable and nothing else),
so it cannot compute parity at length 2. This pass lands the structural
lemma (a depth-0 circuit is exactly an input gate); the concrete depth-0
exclusion of parity and the depth-∞ switching-lemma reduction are the
follow-up (tracked in #72 Pass 2's continuation).
-/

/-- A depth-0 circuit is an input gate: `depth c = 0` forces `c = input i`
  for some variable `i` (every non-input gate has depth at least 1). -/
theorem depth_eq_zero_iff_input {n : Nat} (c : BoolGate n) :
    BoolGate.depth c = 0 ↔ ∃ i : Fin n, c = BoolGate.input i := by
  constructor
  · intro hd
    cases c with
    | input i => exact ⟨i, rfl⟩
    | and a b => simp [BoolGate.depth] at hd
    | or a b => simp [BoolGate.depth] at hd
    | not a => simp [BoolGate.depth] at hd
  · rintro ⟨i, rfl⟩
    simp [BoolGate.depth]


/-! ## AC0 lower-bound structural core -- depth-1 exclusion (issue #72 Pass 2)

The second rung of the depth ladder (after `depth_eq_zero_iff_input`). A
**depth-1** circuit is one gate over input literals: a negated literal, an
AND/OR of literals, or a negated AND/OR over input gates. Parity at length 2
is neither constant nor a (negated) projection, so no depth-1 circuit
computes it. The proof cases on the top gate, uses the depth-0 lemma to
force children to input gates, then closes each concrete two-input shape by
`decide` (the `Fin 2` function space is finite).
-/

/-- **Depth-1 parity exclusion (all shapes).** No length-2 depth-1 circuit
  computes parity. The whole function space `Fin 2 -> Bool` is finite, so
  `decide` closes the universally-quantified shape: for every depth-1
  circuit, some assignment witnesses the failure. -/
theorem not_computes_parity_depth1 :
    forall c : BoolGate 2, BoolGate.depth c = 1 ->
      Not (forall v : Fin 2 -> Bool, BoolGate.eval c v = parity 2 v) := by
  intro c hd
  -- Case on the top gate (named binders); depth-1 forces each child to be
  -- depth-0 (an input gate), after which `decide` closes the concrete
  -- two-input shape.
  cases c with
  | input i => simp [BoolGate.depth] at hd
  | and a b =>
      have hda : 1 + max (BoolGate.depth a) (BoolGate.depth b) = 1 := by
        simpa [BoolGate.depth] using hd
      have ha0 : BoolGate.depth a = 0 := by omega
      have hb0 : BoolGate.depth b = 0 := by omega
      rcases (depth_eq_zero_iff_input a).1 ha0 with ⟨ia, rfl⟩
      rcases (depth_eq_zero_iff_input b).1 hb0 with ⟨ib, rfl⟩
      fin_cases ia <;> fin_cases ib <;> decide
  | or a b =>
      have hda : 1 + max (BoolGate.depth a) (BoolGate.depth b) = 1 := by
        simpa [BoolGate.depth] using hd
      have ha0 : BoolGate.depth a = 0 := by omega
      have hb0 : BoolGate.depth b = 0 := by omega
      rcases (depth_eq_zero_iff_input a).1 ha0 with ⟨ia, rfl⟩
      rcases (depth_eq_zero_iff_input b).1 hb0 with ⟨ib, rfl⟩
      fin_cases ia <;> fin_cases ib <;> decide
  | not a =>
      have ha0 : BoolGate.depth a = 0 := by
        simpa [BoolGate.depth] using hd
      rcases (depth_eq_zero_iff_input a).1 ha0 with ⟨ia, rfl⟩
      fin_cases ia <;> decide

/-! ## AC0 lower-bound structural core — the depth-1 gate-shape characterisation

The counting step the switching lemma is *about*, in its base case: **every
depth-1 circuit is a single gate over input literals**. This is what lets a
random restriction shrink a circuit by one level — a depth-1 gate has no
strictly-lower non-input gate to recurse into, so its depth is decided by the
restriction's action on its literal set alone. It generalises
`depth_eq_zero_iff_input` one rung and is the structural invariant the Pass-2
depth-reduction consumes. -/

/-- A `depth c = 1` circuit is exactly one gate over input literals: a negated
  input, an AND/OR of two inputs, or a negated AND/OR of two inputs. Proved by
  case on the top gate, using `depth_eq_zero_iff_input` to force each child to
  a depth-0 input gate. -/
theorem depth1_shapes_input {n : Nat} (c : BoolGate n) (hc : BoolGate.depth c = 1) :
    (∃ i : Fin n, c = BoolGate.not (BoolGate.input i)) ∨
    (∃ i j : Fin n, c = BoolGate.and (BoolGate.input i) (BoolGate.input j)) ∨
    (∃ i j : Fin n, c = BoolGate.or (BoolGate.input i) (BoolGate.input j)) ∨
    (∃ i j : Fin n, c = BoolGate.not (BoolGate.and (BoolGate.input i) (BoolGate.input j))) ∨
    (∃ i j : Fin n, c = BoolGate.not (BoolGate.or (BoolGate.input i) (BoolGate.input j))) := by
  cases c with
  | input i => simp only [BoolGate.depth] at hc; omega
  | and a b =>
      have h : 1 + max (BoolGate.depth a) (BoolGate.depth b) = 1 := by
        simpa only [BoolGate.depth] using hc
      have ha0 : BoolGate.depth a = 0 := by omega
      have hb0 : BoolGate.depth b = 0 := by omega
      rcases (depth_eq_zero_iff_input a).1 ha0 with ⟨i, rfl⟩
      rcases (depth_eq_zero_iff_input b).1 hb0 with ⟨j, rfl⟩
      exact Or.inr (Or.inl ⟨i, j, rfl⟩)
  | or a b =>
      have h : 1 + max (BoolGate.depth a) (BoolGate.depth b) = 1 := by
        simpa only [BoolGate.depth] using hc
      have ha0 : BoolGate.depth a = 0 := by omega
      have hb0 : BoolGate.depth b = 0 := by omega
      rcases (depth_eq_zero_iff_input a).1 ha0 with ⟨i, rfl⟩
      rcases (depth_eq_zero_iff_input b).1 hb0 with ⟨j, rfl⟩
      exact Or.inr (Or.inr (Or.inl ⟨i, j, rfl⟩))
  | not a =>
      have h : 1 + BoolGate.depth a = 1 := by
        simpa only [BoolGate.depth] using hc
      have ha0 : BoolGate.depth a = 0 := by omega
      rcases (depth_eq_zero_iff_input a).1 ha0 with ⟨i, rfl⟩
      exact Or.inl ⟨i, rfl⟩

/-- **Every circuit of depth ≤ 1 is a gate over input literals.** The
  `depth1_shapes_input` characterisation extended down to depth 0 (a bare
  input), so a single lemma enumerates all depth-≤1 shapes. This is the
  induction's base case in the form the Pass-2 depth-reduction consumes: a
  depth-≤1 circuit has no strictly-lower *non-input* gate to recurse into, so
  a random restriction decides its depth from its literal set alone. -/
theorem depth_le_one_shapes {n : Nat} (c : BoolGate n) (hc : BoolGate.depth c ≤ 1) :
    (∃ i : Fin n, c = BoolGate.input i) ∨
    (∃ i : Fin n, c = BoolGate.not (BoolGate.input i)) ∨
    (∃ i j : Fin n, c = BoolGate.and (BoolGate.input i) (BoolGate.input j)) ∨
    (∃ i j : Fin n, c = BoolGate.or (BoolGate.input i) (BoolGate.input j)) ∨
    (∃ i j : Fin n, c = BoolGate.not (BoolGate.and (BoolGate.input i) (BoolGate.input j))) ∨
    (∃ i j : Fin n, c = BoolGate.not (BoolGate.or (BoolGate.input i) (BoolGate.input j))) := by
  have h01 : BoolGate.depth c = 0 ∨ BoolGate.depth c = 1 := by omega
  rcases h01 with h0 | h1
  · exact Or.inl ((depth_eq_zero_iff_input c).1 h0)
  · exact Or.inr (depth1_shapes_input c h1)

end Circuits

end PleaNP
