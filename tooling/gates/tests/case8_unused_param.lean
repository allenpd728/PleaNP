-- Mock case 8: unused definition parameters (Flaw A shape -- the
-- `DecidesInTime` whose time bound, encoding, and machine never occur in
-- the body). The definition is constant in the things it claims to
-- constrain.
--
-- Expected: VIOLATION unused_param for `M` and `t`. The `∀ x` and `∃ out`
-- binders are used -- no quantifier findings.

namespace PleaNP.Mock

-- A "decision" predicate whose machine and time-bound parameters are never
-- used in the body: it holds of every language regardless of M and t.
def DecidesLike (M : Nat) (t : Nat → Nat) (L : Set Nat) : Prop :=
  ∀ x : Nat, ∃ out : Bool, out = true ↔ x ∈ L

end PleaNP.Mock
