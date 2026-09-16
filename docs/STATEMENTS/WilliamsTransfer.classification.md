# Williams transfer — barrier classification note (issue #91 / #73)

**Status:** Asserted 2026-09-13 (issue #91 Pass 4). The per-technique
*proofs* land in #73 (the Rung-4 classification issue) against the
`NonRelativizing` / `NonNatural` / `NonAlgebrizing` marker classes in
`lean/PleaNP/Barriers/WilliamsTransfer.lean`. This note records the reason
for each — the assert-the-classification deliverable of #91 / #76.
The Lean classification record is `assembled_classification` in
`lean/PleaNP/Barriers/WilliamsAssembly.lean`.

The Williams STOC 2011 lower bound `NEXP ⊄ ACC⁰` is famously the one known
circuit lower bound that avoids all three barriers:

## 1. Non-relativizing

**Reason:** the transfer is an *algorithm-vs-circuits* argument, not an
oracle-relativization argument. It proceeds by (i) exhibiting a
sub-exponential ACC⁰-CircuitSAT algorithm and (ii) showing via a
time-hierarchy-style counting that such an algorithm would contradict every
NEXP function being ACC⁰-computable. Both steps are carried out on the
plain (non-oracular) circuit/class substrate; they do not survive being
re-run "relative to an arbitrary oracle" in the Baker–Gill–Solovay manner —
the algorithm's existence and the counting are specific to the un-relativized
universal computation. (Contrast: the parity ∉ AC⁰ proof *does* relativize
— it never uses oracle access, #73 Pass 2.)

**Consequence:** a relativizing-proof barrier does not apply; the standard
BGS oracle-separation argument cannot rule `NEXP ⊄ ACC⁰` out.

## 2. Non-natural

**Reason:** the proof does not proceed by exhibiting a *large, constructive
property* of Boolean functions that every ACC⁰ function avoids
(Razborov–Rudich's natural-proof template). The transfer shows the
*existence* of a hard NEXP function via the CircuitSAT-algorithm
contrapositive, not by constructing a uniform property `C = {Cₙ}`
distinguishing hard functions with `Cₙ` large and poly-time-checkable.
The algorithm itself is the witness, not a largeness/constructivity pair —
so the RR "natural proofs break under OWFs" objection does not apply.

**Consequence:** the cryptographic barrier on natural lower bounds does not
block the Williams bound.

## 3. Non-algebrizing

**Reason:** the algebrization barrier (Aaronson–Wigderson) applies to proofs
that still work when the simulating machine gets oracle access to a
*low-degree extension* of the oracle. The Williams transfer's circuit-model
argument has no oracle to extend: it arithmetizes over the circuit
evaluation semantics, and giving the machines access to an algebraic
extension of an oracle changes the ACC⁰-circuit question the argument
quantifies over (the computation is over the plain circuit family, not an
oracle-augmented one). The AW09 oracle pairs that witness P^A = NP^A /
P^B ≠ NP^B under extension access do not transfer to the circuit setting.

**Consequence:** the algebrization oracle witness does not apply; the bound
survives the third barrier as well.

## The marker classes (Lean)

`NonRelativizing p` / `NonNatural p` / `NonAlgebrizing p` are zero-data
marker classes in `WilliamsTransfer.lean`; `#73` supplies instances (the
proofs of each classification) where the instance machinery exists. Until
then the note above is the asserted record per #91/#76 DoD.
