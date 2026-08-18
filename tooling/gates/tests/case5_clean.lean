-- Mock case 5: a clean file. No violations, no smells (except legit decide).
-- Should pass Tier 1 in both stages with zero violations.

namespace PleaNP.Clean

theorem real_proof : 2 + 2 = 4 := by decide

theorem another : True := trivial

end PleaNP.Clean
