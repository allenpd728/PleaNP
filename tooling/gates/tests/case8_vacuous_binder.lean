-- Mock case 8: weakly constrained quantifier witness (Flaw C shape -- the
-- `NP_A` certificate). The `∃ y` binder constrains only the length conjunct;
-- the acceptance conjunct doesn't mention `y`, so the witness is vacuous
-- beyond a bound that `y = 0` always satisfies.
--
-- Expected: REVIEW weakly_constrained_witness for `y` (the `Accepts M (x, 0)`
-- conjunct doesn't mention it); REVIEW unreferenced_decl for `Verifies`
-- (nothing calls it). Zero violations: `y` does occur in the body.

namespace PleaNP.Mock

def Accepts (M : Nat) (input : Nat × Nat) : Prop := input.1 > M

-- The verifier-framing trap: acceptance must depend on the certificate y,
-- but here `Accepts` is applied to (x, 0) regardless of y.
def Verifies (M : Nat) (L : Set Nat) (p : Nat → Nat) : Prop :=
  ∀ x : Nat, x ∈ L ↔ ∃ y : Nat, y ≤ p x ∧ Accepts M (x, 0)

end PleaNP.Mock
