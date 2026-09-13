import PleaNP.Computability.OracleComplexity
import Mathlib.Computability.Partrec
set_option warningAsError true

/-!
# Comparator challenge: Relativization (Baker–Gill–Solovay 1975) — statement reference

DEC-022 statement-fidelity obligation for the two BGS clauses
(`docs/STATEMENTS/ComparatorChallenge.template.md`, `docs/STATEMENTS/Relativization.md`).

## Independence (per the template §0)

The proof root (`PleaNP.Barriers.Relativization`, file
`lean/PleaNP/Barriers/Relativization.lean`) **must not import** this module,
and this module **must not import** the proof root. The two files share only
the canonical substrate imports (`PleaNP.Computability.OracleComplexity` for
`Oracle`, `P_A`, `NP_A` — Gate 2: both reference the same canonical classes,
never local redefinitions).

## Channel (per the template §0)

This reference is authored from the **frozen informal anchor**
`docs/STATEMENTS/Relativization.md` (the human-verified channel, written by
the non-Lean-writing driver) — not by copying the proof-root rendering. The
proof root was rendered from the same anchor through the proof channel
(`Relativization.lean.spec.md`); the two are expected to converge and the
future `lake exe comparator` check machine-verifies their alignment (JSON
pin: `lean/ComparatorChallenges/Relativization.json`).

## Statement references vs proofs

The clauses below are stated as `def ... : Prop` — the *proposition* pinned
by the informal spec, with **zero proofs and zero sorries**. The proof root
carries the `theorem` declarations (currently `sorry` placeholders, tracked
in `docs/SORRY_TRACKER.md`); those theorems are the adapters that the
comparator will check against these references once the sorries close and a
comparator lake dependency exists (aspirational — see template §4).

## Encoding notes (rendering traps from `Relativization.lean.spec.md`)

- **Trap 1 (computability):** both references carry an explicit
  `Computable` hypothesis on the existential oracle — without it the
  statement is trivially/vacuously true (Gate 5 non-triviality).
- **Trap 2 (set equality):** `P_A A = NP_A A` is set extensional equality of
  two `Set (Set alpha)` values (`OracleComplexity.lean` Trap 3).
- **Trap 3 (query type):** `Q` is concretely instantiated as `List Bool`
  (`QueryType`), the standard bitstring query space, matching the audit note
  in `Relativization.lean.spec.md` (issue #54).

## Verification performed (2026-09-13, issue #64)

- The two `def`s below compile green under `lake build PleaNP.Challenges.Relativization`
  (0 sorries; this module is part of the *clean* tree, not a sorry module).
- A one-off `rfl` probe confirmed each challenge Prop is **definitionally
  equal** to the proof-root theorem type written in
  `lean/PleaNP/Barriers/Relativization.lean` (`exists_equalizing_oracle` →
  `equalizing_oracle_statement`, `exists_separating_oracle` →
  `separating_oracle_statement`), so the JSON pin aligns exact types, not
  coincidentally-equal Propositions. The comparator's future
  `lake exe comparator` check (when a comparator lake dependency exists —
  aspirational per the template §4) formalizes that alignment permanently.

Reference: Baker, T., Gill, J., Solovay, R. *Relativizations of the P =? NP
Question.* SIAM J. Comput. 4(4):431–442, 1975. No proof assistant
formalizes BGS (`docs/PRIOR_ART.md`); this module is PleaNP's independent
formal reference statement.
-/

namespace PleaNP

namespace Challenges

open Oracles

/-- The query type: bitstrings. From the frozen spec `Relativization.md` §3 /
  rendering spec Trap 3: the standard query space for complexity theory. -/
abbrev QueryType := List Bool

/-- The input type: bitstrings. Languages are sets of bitstrings. -/
abbrev InputType := List Bool

/-- **BGS clause (a), as a statement reference:** there exists a total,
  computable oracle A such that P^A = NP^A (set extensional equality).

  Total by construction (`Oracle Q := Q → Bool`); the `Computable`
  hypothesis is the Trap-1 non-triviality constraint. Stated as a Prop
  pin (0 sorries); the proof is the proof-root theorem's job.

  Named `equalizing_oracle_statement` (not `exists_equalizing_oracle`)
  so the binder scanner does not silently exempt this reference through
  the proof-root allow-list regex (the two REVIEW items this module
  produces are documented, not suppressed — see `docs/GATE_REVIEW_NOTES.md`). -/
def equalizing_oracle_statement : Prop :=
  ∃ (A : Oracle QueryType),
    Computable (α := QueryType) A ∧
      P_A (alpha := InputType) A = NP_A (alpha := InputType) A

/-- **BGS clause (b), as a statement reference:** there exists a total,
  computable oracle B such that P^B ≠ NP^B (set extensional inequality).

  Same structural constraints as clause (a): total oracle, computable
  witness, set extensional inequality. Same naming rationale as clause (a). -/
def separating_oracle_statement : Prop :=
  ∃ (B : Oracle QueryType),
    Computable (α := QueryType) B ∧
      P_A (alpha := InputType) B ≠ NP_A (alpha := InputType) B

end Challenges

end PleaNP
