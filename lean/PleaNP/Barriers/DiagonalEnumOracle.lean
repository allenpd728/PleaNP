import PleaNP.Barriers.DiagonalEnum
import PleaNP.Computability.Oracle

set_option warningAsError true

/-!
# BGS diagonalization D6/O1: the oracle code-space and its enumeration

`DiagonalEnum.M_of : Nat → Nat.Partrec.Code` enumerates *oracle-free* programs,
so `DiagonalAssembly.Simulate i k n := evaln k (M_of i) n` cannot model a machine
whose computation depends on the oracle `B`. This module supplies the missing
oracle code-space and its enumeration (issue #154, split out of #37).

## The type

`OracleCode Q` pairs a partial-recursive program with the oracle it queries. The
oracle is carried as a *field*, so `oracleOf` is a real projection — but it is a
**pinned** value in every use the tournament makes: `DiagonalSyntax` proved that
`P_A A`/`NP_A A` witnesses fix `M.oracle = A`, so the oracle is not a degree of
freedom in the diagonalization.

## Why the enumeration is over the pinned space

`Oracle Q = Q → Bool` is **not** countable when `Q` is infinite (the BGS query
space is `Σ n, Bits n`), so there is no `Denumerable (Oracle Q)` and hence no
`Denumerable (Oracle Q × Code)` — the issue's suggested type is not enumerable.
The enumerable content is the *program*, with the oracle held fixed. The
enumeration therefore lives on the pinned subtype
`{ c : OracleCode Q // c.oracle = A }`, which is denumerable because it is
equivalent to `Nat.Partrec.Code` (`pinnedEquiv`). `M_of_oracle A i` is the `i`-th
program enumerated for the fixed oracle `A`, so `(M_of_oracle A i).prog` is
exactly `DiagonalEnum.M_of i` — the enumeration the tournament already simulates.
-/

namespace PleaNP

namespace Barriers

namespace DiagonalEnumOracle

open PleaNP.Oracles

/-- An oracle-machine program: a partial-recursive program (`Nat.Partrec.Code`)
  together with the oracle it queries. The oracle is pinned by the class witness
  (`DiagonalSyntax.mem_P_A_oracle_pinned`), not enumerated. -/
structure OracleCode (Q : Type) where
  prog : Nat.Partrec.Code
  oracle : Oracle Q

/-- The program part of an oracle code. -/
def prog {Q : Type} (c : OracleCode Q) : Nat.Partrec.Code := c.prog

/-- The oracle an oracle code queries. -/
def oracleOf {Q : Type} (c : OracleCode Q) : Oracle Q := c.oracle

/-- The oracle-pinned subspace: oracle codes that query a fixed oracle `A`.
  This is the space the tournament enumerates — all machines with oracle `A`. -/
abbrev PinnedOracleCode (Q : Type) (A : Oracle Q) := { c : OracleCode Q // c.oracle = A }

/-- The pinned space is the oracle-free code space: projecting to the program is a
  bijection (the oracle is determined by the pin). -/
def pinnedEquiv (Q : Type) (A : Oracle Q) : PinnedOracleCode Q A ≃ Nat.Partrec.Code where
  toFun c := c.1.prog
  invFun k := ⟨⟨k, A⟩, rfl⟩
  left_inv c := by
    obtain ⟨⟨k, o⟩, ho⟩ := c
    subst ho
    rfl
  right_inv k := rfl

/-- The pinned space is denumerable — it is equivalent to `Nat.Partrec.Code`. This
  is the enumeration the tournament walks: it enumerates *programs*, with the
  oracle pinned by the class, exactly per `DiagonalSyntax`'s corrected analysis. -/
noncomputable instance pinnedDenumerable (Q : Type) (A : Oracle Q) :
    Denumerable (PinnedOracleCode Q A) :=
  Denumerable.ofEquiv Nat.Partrec.Code (pinnedEquiv Q A)

/-- `M_of_oracle A i` is the `i`-th program enumerated for the fixed oracle `A`. -/
noncomputable def M_of_oracle (Q : Type) (A : Oracle Q) (i : Nat) : OracleCode Q :=
  (Denumerable.ofNat (PinnedOracleCode Q A) i).1

/-- The enumeration projects onto the oracle-free enumeration: the `i`-th program
  for oracle `A` is exactly `DiagonalEnum.M_of i`. This is the bridge that lets
  `DiagonalAssembly.Simulate` use `M_of_oracle` in place of `M_of`. -/
@[simp]
lemma M_of_oracle_prog (Q : Type) (A : Oracle Q) (i : Nat) :
    (M_of_oracle Q A i).prog = DiagonalEnum.M_of i := by
  unfold M_of_oracle
  rw [Denumerable.ofEquiv_ofNat]
  rfl

/-- Every enumerated code queries the pinned oracle `A`. -/
@[simp]
lemma M_of_oracle_oracle (Q : Type) (A : Oracle Q) (i : Nat) :
    (M_of_oracle Q A i).oracle = A := by
  unfold M_of_oracle
  rw [Denumerable.ofEquiv_ofNat]
  rfl

/-- Encode round-trip, mirroring `DiagonalEnum.code_ofNat_encode`: enumerating the
  pinned space and then encoding recovers the index. -/
lemma code_ofNat_encode (Q : Type) (A : Oracle Q) (n : Nat) :
    Encodable.encode (Denumerable.ofNat (PinnedOracleCode Q A) n) = n :=
  Denumerable.encode_ofNat (α := PinnedOracleCode Q A) n

/-- Encode round-trip, mirroring `DiagonalEnum.code_encode_ofNat`: every pinned
  oracle code appears in the enumeration. -/
lemma code_encode_ofNat (Q : Type) (A : Oracle Q) (c : PinnedOracleCode Q A) :
    Denumerable.ofNat (PinnedOracleCode Q A) (Encodable.encode c) = c :=
  Denumerable.ofNat_encode (α := PinnedOracleCode Q A) c

/-- **Bounded-simulate compatibility (oracle-free sub-case).** The bounded
  simulation of an oracle code's program under the empty oracle is exactly the
  bounded simulation of the oracle-free enumeration — so `DiagonalAssembly`'s
  `Simulate` over `M_of` is recovered as the `A = emptyOracle` instance. -/
lemma evaln_oracle_free (Q : Type) (k n i : Nat) :
    Nat.Partrec.Code.evaln k (M_of_oracle Q (emptyOracle Q) i).prog n
      = Nat.Partrec.Code.evaln k (DiagonalEnum.M_of i) n := by
  rw [M_of_oracle_prog]

/-- The empty-oracle oracle code is the oracle-free program: the oracle-free
  sub-case is literally a member of the oracle code-space. -/
lemma emptyOracle_prog (Q : Type) (i : Nat) :
    (M_of_oracle Q (emptyOracle Q) i).prog = DiagonalEnum.M_of i :=
  M_of_oracle_prog Q (emptyOracle Q) i

end DiagonalEnumOracle

end Barriers

end PleaNP
