# Failure audit: prior attempts at "formalized P vs NP" and how they failed

This document encodes the lessons from prior attempts so that future contributors (human or AI) inherit them. It is first-class documentation because the #1 thing that kills projects like this is repeating the same failure modes.

---

## The meta-failure (most important)

> **Formalization does not confer correctness of the statement-to-informal mapping.**

Every "compiled, zero-sorry" P vs NP proof in the record failed not because Lean rejected it, but because the Lean statement encodes something weaker or different from the actual P vs NP problem. A compiling proof of the *wrong statement* is worse than no proof, because it looks authoritative.

This is why the integrity gates (see `docs/ARCHITECTURE.md`) exist: statement formalization and proof search must be isolated, with the statement's equivalence to informal P vs NP established as a separate, human-verified artifact.

---

## Pattern A — Crank/cottage-industry "P ≠ NP formalized in Lean/Coq" claims

**Failure mode:** The formalization isn't of the real statement.

### Examples in the record (2025–2026)

- **"Homological proof of P ≠ NP" (arXiv 2510.17829).** Claims a Lean 4 + Mathlib formalization using "computational categories" and homology — "if L ∈ P then C₊(L) is contractible" and "SAT formulas with H₁ ≠ 0." Red flags: a novel exotic framework, a topological invariant claimed to separate P from NP, self-verified formalization by the author. A contractibility/acyclicity argument is exactly the kind of "natural" property the natural-proofs barrier predicts will fail.

- **"P = NP via the Pedigree Polytope Membership Problem" (arXiv 2606.03194).** Claims a zero-sorry Lean 4 proof with "2968 build targets." The author "had never undertaken [Lean formalization] before." Correctness depends entirely on whether the formalized statement matches informal P = NP — and that mapping is not independently verified.

- **konard/p-vs-np (GitHub).** The most disciplined of these — explicitly catalogues historical failed attempts (Ted Swart's 1986/87 LP-based P=NP, refuted by Yannakakis 1988) and is honest that only P ⊆ NP is proven. But the "P ≠ NP formalization frameworks" are scaffolding for checking hypothetical proofs, not evidence.

- **Connell "Super-Complexity."** Claims a Coq-verified non-relativizing, non-naturalizing, non-algebrizing separation, combined with building "an entire cryptographic stack on top." The overclaim signature.

**The integrity rule for PleaNP:** If the same person (or the same pipeline) writes the statement and the proof, a compiling proof just means the statement isn't the real P vs NP. → Gates 1, 3, 4 in `ARCHITECTURE.md`.

---

## Pattern B — Serious complexity formalization that succeeded but revealed the cost

**Failure mode (such as it is):** Underestimating the computational-model substrate cost. These are honest, high-quality successes that show the price of admission.

### Precedents

- **Gäher & Kunze, "Mechanising the Cook-Levin Theorem in Coq" (ITP 2021).** Real, peer-reviewed, correct. Used the λ-calculus L as model. Required the Forster-Kunze-Wuttke-Smolka model-equivalence result (L ↔ TMs, polynomial overhead) *first* — a large substrate before the actual theorem.

- **Balbach, Cook-Levin in Isabelle (AFP, 2023).** Same theorem, TM model, "elementary, if not brute-force." Confirms the TM route is grueling.

- **Forster-Kunze-Lauermann, "Synthetic Kolmogorov Complexity in Coq" (ITP 2022).** Shows the "synthetic computability" approach (assuming Church's Thesis as an axiom) dramatically lowers the "invisible mathematics" overhead that Forster warned makes complexity formalization expensive.

- **Statistical learning theory formalization in Lean 4 (2026).** A human-AI collaborative formalization that "exposes and resolves implicit assumptions and missing details" in the source theory. Closest precedent to PleaNP's intended workflow: human-strategy + AI-tactics. Honest framing: the value was *clarifying the theory*, not solving open problems.

**The lesson for PleaNP:** Every serious success required (a) committing to a computational model, (b) building model-equivalence lemmas first, and (c) accepting that the first payoff is a cleaner library and pedagogy, not a new theorem. → Rungs 2–4 in `ROADMAP.md` build the substrate; Rung 1 (`GAP_AUDIT.md`) tells us how much already exists.

---

## Pattern C — AI proof-search that hit integrity walls

**Failure mode:** AI producing a green checkmark that isn't a proof. Most relevant to PleaNP's Rung 6.

### Precedents

- **The Collatz-in-Lean LLM incident.** An LLM-generated Lean "proof" of Collatz compiled by exploiting a (real, then-fixed) bug in the Lean kernel. Takeaway: an AI producing a green checkmark is not the same as a proof existing. The verification pipeline must treat the kernel as one trust boundary, not the only one.

- **Autoformalization robustness gap (2026 study).** Current autoformalizers are *not* faithful under paraphrase — they pass the compiler on subtly wrong statements. This is the statement-fidelity problem (Pattern A) measured quantitatively in the AI setting. Direct technical risk for any retrieval/autoformalization component.

- **The "independent formalization" rule, restated for AI.** The Fortnow blog commenter's rule — "get someone else to formalize the statement, then you prove it" — has an AI corollary: statement formalization and proof search must be isolated, with the statement anchored to a human-verified spec. Current agent designs (OpenProver, LeanFlow, 2026) grapple with this via "code hygiene" scans but are not built for the adversarial integrity case a P vs NP claim demands.

**The lesson for PleaNP:** AI proof systems today are tuned for benchmarks (MiniF2F, ~80–92% with huge search budgets) on *already-correct, already-formalized statements*. The moment the AI also chooses/defines the statement against an informal target as slippery as P vs NP, you are in Pattern A territory with AI speed. → Gates 1–6 must be fully in place before Rung 6 runs.

---

## What is NOT in the record (and why it matters)

There is **no record of a serious, multi-year, well-resourced attempt to formalize the barrier theorems themselves** (relativization, natural proofs, algebrization) as a deliberate foundation for P vs NP work.

People formalize Cook-Levin because it's the famous theorem. Nobody has built the *anti-pattern library* — the formalized catalog of "techniques that provably cannot work."

That is genuinely open ground, it is exactly the substrate an AI search needs, and it is PleaNP's core contribution (Rung 3).

---

## Quick reference: the failure-mode-to-gate mapping

| Failure mode | Pattern | Gate that blocks it |
|---|---|---|
| Statement quietly edited to be provable | A | Gate 1 (statement-freeze) |
| NP redefined as something weaker | A | Gate 2 (model-consistency) |
| Single formalization encodes wrong claim | A, C | Gate 3 (statement-fidelity) |
| Statement compiles but means wrong thing | A, C | Gate 4 (read-back) |
| Vacuous / trivially-true statement | A | Gate 5 (non-triviality) |
| Hidden `sorry` / custom axioms | A, C | Gate 6 (hygiene) |
| AI exploits kernel fragility | C | Kernel treated as one boundary, not the only one |
| AI autoformalizes subtly wrong statement | C | Gates 3, 4 (independent + read-back) |

---

## Sources

This audit is synthesized from public records (2023–2026) including:
- Fortnow, "Do We Need to Formalize?" (Computational Complexity blog, 2023) and the Forster/Balbach discussion therein
- MathOverflow, "Should we trust AI-generated formal proofs in Lean 4?"
- MathOverflow, "Proofs shown to be wrong after formalization with proof assistant"
- Aaronson, "Eight Signs A Claimed P≠NP Proof Is Wrong"
- Gäher & Kunze, ITP 2021; Balbach, AFP 2023; Forster et al., ITP 2022
- The 2026 autoformalization robustness study
- arXiv preprints 2510.17829, 2606.03194 (treated as claims, not results)

Individual citations are maintained in `docs/decisions/LOG.md` entries where they inform a design choice.
