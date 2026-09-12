-- Mock case 13: elaborator-command (elab_rules) and `#barrier_check <id>` script
-- invocations keep helper declarations alive (#2).
--
-- `helperStatic` is referenced only inside the `elab_rules` body (which the old
-- DECL_START_RE-only split attached to `helperStatic`'s OWN block, so its
-- reference was skipped as self-reference → false-positive unreferenced_decl).
-- `checkedDecl` is referenced only by the `#barrier_check checkedDecl` script line
-- (which the old split put inside `checkedDecl`'s OWN block → hidden).
--
-- Expected with the #2-aware split: ZERO findings (the two pseudo-blocks act as
-- reference sources;and `elab`/`check` pseudo-kinds are never flagged themselves),
-- exit  0, even without --allow-unreferenced.

namespace PleaNP.Mock

/-- Referenced only from inside the elaborator command body. -/
def helperStatic (q : Nat) (oracle : Nat → Bool) : Nat :=
  if oracle q = true then q else 0

/-- Scripted check target:referenced only by the `#barrier_check` line below. -/
theorem checkedDecl : ∀ x : Nat, x ≤ x +  1 :=by
  intro x
  omega

elab_rules : command
  | `(command| #mock_check $id:ident) => do
    let n := (id.getId).toString
    let h : Nat → Nat := helperStatic 0
    logInfo m!"mock #mock_check {n} (helper {h} = true)"

#barrier_check checkedDecl

end PleaNP.Mock