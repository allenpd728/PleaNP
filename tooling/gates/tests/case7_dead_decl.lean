-- Mock case 7: discarded let-binding + unreferenced declaration (Flaw B
-- shape -- `oracleQuery` computes the oracle's answer, throws it away, and
-- is never wired into `step`).
--
-- Expected: REVIEW discarded_let for `_answer`; REVIEW unreferenced_decl
-- for `queryHelper`. No violations. `step` IS referenced (by `queryHelper`)
-- so it must NOT be flagged.

namespace PleaNP.Mock

def step (n : Nat) : Nat := n + 1

-- Consults the oracle, discards the answer, and is never called by anything.
def queryHelper (q : Nat) (oracle : Nat → Bool) : Nat :=
  let _answer := oracle q
  step q

end PleaNP.Mock
