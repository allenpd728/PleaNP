-- Mock case 12: a file with a docstring that quotes -/ inside a string,
-- which used to make the comment-stripper swallow the rest of the file
-- (a Gate-6 false NEGATIVE). Regression test for the scanner fix.

/-!
A docstring that mentions none -- the string contains -/ and the
stripper must NOT stop here.
-/

namespace PleaNP.Gate6Regression

/-- Also a docstring with a literal x -/ y inside backticks. -/
theorem some_def : Nat := 42

-- The real sorry below must be caught (Tier 1 prove-stage).
theorem has_sorry : False := by
  sorry

end PleaNP.Gate6Regression
