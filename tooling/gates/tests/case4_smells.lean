-- Mock case 4: smell tactics (legit but worth review) and a comment-protected
-- `sorry` (inside a block comment) which must NOT be flagged.

namespace PleaNP.Misc

-- This sorry is inside a block comment: /- sorry -/ — must not be flagged.
theorem closes_with_decide : 2 + 2 = 4 := by decide

theorem closes_with_exact_q : True := by exact? trivial

-- irreducible hiding a def — flag for review
private irreducible def hiddenThing : Nat := 0

end PleaNP.Misc
