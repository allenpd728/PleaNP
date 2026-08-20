-- Test case: dead binders and unused parameters (should flag)
-- The parameter `t` is not referenced in the body.
def bad_decides (ea : Nat -> List Nat) (t : Nat -> Nat) : Prop :=
  forall x, True

-- The bound variable `y` in `exists y` does not appear in the conjunct.
def bad_np : Set (Set Nat) :=
  { L | exists (y : List Nat), True }

-- Load-bearing (should NOT flag): both parameters used, both binders load-bearing.
def good_decides (ea : Nat -> List Nat) (t : Nat -> Nat) : Prop :=
  forall x, exists cfg, cfg = ea x
