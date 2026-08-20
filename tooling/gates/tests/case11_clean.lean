-- Mock case 11: a clean file. Every parameter is load-bearing, every
-- quantifier binder constrains all top-level conjuncts, and every
-- declaration except the entry point is referenced.
--
-- Expected with default flags: exactly one REVIEW (unreferenced_decl for
-- `entry_point` -- the top of every reference chain is unreferenced by
-- construction), zero violations, exit 0.
-- Expected with --allow-unreferenced '^entry_point$': zero findings
-- (exit 0 even under --strict). This also exercises the allow-list flag.

namespace PleaNP.Mock

def AcceptsInTime (M : Nat) (x : Nat) (steps : Nat) : Prop := x ≤ steps + M

def DecidesWell (M : Nat) (t : Nat → Nat) (L : Set Nat) : Prop :=
  ∀ x : Nat, ∃ steps : Nat, steps ≤ t x ∧ (AcceptsInTime M x steps ↔ x ∈ L)

theorem decidesWell_of_le (M : Nat) (t : Nat → Nat) (L : Set Nat)
    (h : DecidesWell M t L) : ∃ M' : Nat, M' = M ∧ M' ≤ M := by
  have h' := h
  exact ⟨M, rfl, le_refl M⟩

theorem entry_point : ∃ M' : Nat, M' = 0 ∧ M' ≤ 0 :=
  decidesWell_of_le 0 id Set.univ (fun x => ⟨x, Nat.le_refl x, by simp [AcceptsInTime]⟩)

end PleaNP.Mock
