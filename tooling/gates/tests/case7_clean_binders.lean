-- Test case: clean definitions (should NOT flag)
def good_machine (oracle : Nat -> Bool) (queryLabel : Nat) : Prop :=
  oracle queryLabel = true

def good_np : Set (Set Nat) :=
  { L | exists (y : List Nat), y.length > 0 /\ True }
