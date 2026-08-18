-- Mock case 1: render-stage placeholder. `:= by sorry` is EXPECTED and ALLOWED
-- during statement rendering (LOCAL_AGENT_WORKFLOW Step 1). In render-stage
-- mode (default), this file should be CLEAN. In --prove-stage mode, it's a
-- violation.

namespace PleaNP.Barriers.Relativization

-- (a) Existence of a separating oracle — placeholder proof.
theorem exists_oracle_p_ne_np : True := by sorry

end PleaNP.Barriers.Relativization
