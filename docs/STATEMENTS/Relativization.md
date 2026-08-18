# Statement spec: Relativization (Baker–Gill–Solovay, 1975)

**Rung:** 3a — the first barrier to formalize (`docs/GAP_AUDIT.md` §4, prioritization §2; `docs/ROADMAP.md` Rung 3).
**Status:** Draft scaffold — the informal-to-formal mapping is pinned; the Lean statement shape is provisional pending Rung 2 (oracle machines). This document is the Gate 1 frozen-statement anchor and the Gate 4 read-back reference. It must not be edited by any proof-search pipeline.

---

## 1. Informal statement

**Source:** Baker, T., Gill, J., Solovay, R. *Relativizations of the P =? NP Question.* SIAM Journal on Computing, 4(4):431–442, 1975. (Cited in `docs/PRIOR_ART.md` as the informal source of truth for Gate 4.)

The theorem has two existence clauses:

> **(a)** There exists a recursive set (oracle) **A** such that **P^A = NP^A**.
>
> **(b)** There exists a recursive set (oracle) **B** such that **P^B ≠ NP^B**.

**Barrier consequence (the actual meta-theorem):** Any proof technique that *relativizes* — i.e., that continues to hold when both sides are given access to an arbitrary oracle — cannot resolve P vs NP, because (a) and (b) exhibit oracles on opposite sides. A relativizing proof of P = NP would imply P^B = NP^B for the B of (b), a contradiction; a relativizing proof of P ≠ NP would imply P^A ≠ NP^A for the A of (a), a contradiction.

### Standard construction witnesses (for the formalization target)

These are the canonical witnesses from the literature (e.g. Arora–Barak §3; the cs.wisc.edu / uva.nl lecture notes cited in `docs/PRIOR_ART.md`), not the only ones — the spec pins the *existence* result, but a constructive proof will supply concrete machines.

- **Oracle A (P^A = NP^A):** Take **A = QBF** (or any PSPACE-complete language, e.g. the EXP-complete language `A = {⟨M,x,1^m⟩ : M accepts x in 2^m steps}`). Then `P^A = NP^A = EXP` (or `= PSPACE` for QBF), since one oracle query can perform an exponential-time computation in a single step.
- **Oracle B (P^B ≠ NP^B):** Construct **B** by diagonalization. Define `U_B = {1^n : ∃ x ∈ {0,1}^n, x ∈ B}` (the unary language asking "is there an n-bit string in B"). For every B, `U_B ∈ NP^B` (guess x, query B). B is built in stages so that for every deterministic polynomial-time oracle machine `M_i`, `M_i^B` fails to decide `U_B` on some input `1^n` — by answering "no" to `M_i`'s queries for new strings, then (if `M_i` rejects `1^n`) adding one as-yet-unqueried n-bit string to B. Since `M_i` makes only polynomially many queries but there are `2^n` n-bit strings, such a string always exists.

---

## 2. Dependencies (where each definition must come from)

| Definition | Source | Status |
|---|---|---|
| Turing machine (base model, with step counting) | Upstream Mathlib — one of #35366 (`TM1`+`runN`), #33132 (`FinTM0`), Reitwiessner (#7, multi-tape+space), or complexitylib (#6) | **Blocked** — none landed in Mathlib core (`docs/UPSTREAM_TRACKING.md`) |
| `P` (polynomial time) | Upstream — same model choice as above | Blocked on the model |
| `NP` (nondeterministic poly time / poly-time verifiable) | Upstream | Blocked on the model |
| **Oracle (machine-level: a total function answered in one step)** | **PleaNP-local** — `PleaNP.Oracles` (`docs/GAP_AUDIT.md` §3). Distinct from Mathlib's recursion-theoretic `RecursiveIn` (unbounded time). | **Unblocked** — definable against any chosen base model |
| **Oracle machine (TM + oracle tape)** | **PleaNP-local** | Unblocked (Rung 2 local piece) |
| **`P^A`, `NP^A` (poly-time-bounded oracle computation)** | **PleaNP-local** — the time-complexity layer on top of the oracle machine | Unblocked once oracle machine + base model exist |
| Recursive / decidable oracle (A and B must be computable) | Upstream Mathlib computability (`Turing.Computable`) | Present |

**Key distinction (from `docs/PRIOR_ART.md` §1, GAP_AUDIT §3):** Mathlib's `RecursiveIn.lean` gives oracle *computability* (unbounded). Relativization needs oracle *complexity* — a machine that queries a *total* oracle and halts in *polynomial* time. The totality point matters: per the Edwin Park / Mario Carneiro Zulip discussion (`PRIOR_ART.md` §1), Mathlib's current `TuringReducible` is the partial (enumeration-degree) notion; for oracles that answer in one step, the oracle is total by definition, so PleaNP's oracle machines compose with *total* oracles regardless of the upstream partial-general definition. No conflict, but the naming/totality distinction must be respected in the Lean definitions.

---

## 3. Formalization target (statement shape — no Lean rendering)

Pinned to the **1975 BGS statement** (per the rung-3c precedent in `docs/ROADMAP.md`: pin the original, dated formulation; track later strengthenings separately). The actual Lean rendering is the local agent's job (it requires a landed Rung 2 model and `lake build` validation, which is out of scope for this spec). What follows is the *logical shape* the Lean must express, so the local agent has an unambiguous target:

**Clause (a) — equalizing oracle.** There exists an oracle `A` such that `P^A = NP^A`.
**Clause (b) — separating oracle.** There exists an oracle `B` such that `P^B ≠ NP^B`.

**Constraints the Lean rendering must encode (acceptance criteria for the local agent):**
- The oracle is *existential* and *total* — it answers every query in one step. This is **not** the partial-function oracle of Mathlib's `RecursiveIn`; the local agent must not reuse that type. (See `docs/PRIOR_ART.md` §1, the Park/Carneiro totality discussion.)
- Both witnesses must be **recursive** (computable), not arbitrary. BGS 1975 constructs computable A and B. A statement that quantifies over *all* oracles (including noncomputable ones) is a *different* (and in clause (a)'s case, trivial) theorem — a Gate 5 (non-triviality) failure.
- `P^A = NP^A` is *set extensional equality* of two oracle-relative language classes; `P^B ≠ NP^B` is its negation. The local agent must confirm the upstream `P`/`NP` are *language classes* (sets of languages), not bare decision-problem predicates, so the equality is extensional — a Gate 2 (model-consistency) check item.
- The `U_B` / diagonalization construction for B is the *proof*, not the statement. The statement is pure existence.
- Namespace: `PleaNP.Barriers.Relativization` (per DEC-002, not `Complexity.*`).

The local agent renders this into Lean, runs `lake build`, and the resulting statement is checked against §5 (read-back) before any proof search begins.

---

## 4. Gate mapping (which integrity gates apply, and what each checks here)

Reference: `docs/ARCHITECTURE.md`.

| Gate | What it checks for *this* statement | Failure mode it blocks |
|---|---|---|
| **1 — Statement-freeze** | This spec (and the eventual Lean `Relativization.lean`) is version-controlled and read-only to proof search. | Quietly editing the statement until provable. |
| **2 — Model-consistency** | The statement references the canonical upstream `P`/`NP` (from whichever model lands, `UPSTREAM_TRACKING.md`), not a local redefinition. The oracle is `PleaNP.Oracles.Oracle`, not a local alias of `NP`. | Redefining `NP` weaker and proving that. |
| **3 — Statement-fidelity** | A *second*, independently-produced formalization of BGS must be checked for logical equivalence to this one before trust. | One formalization quietly encoding a weaker existence claim. |
| **4 — Read-back** | An auto-generated informal statement read back from the Lean must match §5 below. | Statement compiles but means something different (e.g. quantifies over partial oracles, or drops the recursiveness hypothesis). |
| **5 — Non-triviality** | The statement is not vacuous: it requires the oracle to be recursive (a real constraint), and does not hold trivially under the chosen axioms. | Proving `∃ A, True` and calling it BGS. |
| **6 — Hygiene** | The eventual proof scans for `sorry`/`admit`/custom axioms. | A "proof" that compiles only via a hidden unproven step. |

**Gate 2 specifics (the encoding trap):** The unary-alphabet trap (`PRIOR_ART.md` §5: "with a unary alphabet, P=NP") is a concrete instance of what Gate 2 blocks for PleaNP generally. For relativization specifically, the analogue is the *partial-vs-total oracle* trap: a statement over partial oracles is a different theorem. The linter must verify the oracle type is total.

---

## 5. Read-back check (Gate 4 acceptance criterion)

The formal Lean statement, when translated back to natural language (by an LLM or rule-based translator), must produce a sentence equivalent to:

> *"There exists a total, computable (recursive) oracle A such that the class of languages decidable in deterministic polynomial time with access to A equals the class decidable in nondeterministic polynomial time with access to A; and there exists a total, computable oracle B such that these two classes are unequal."*

**Disagreement blocks the claim.** Specifically, a read-back that drops any of these is a fail:
- "total" / "computable" (dropping either changes the theorem);
- "polynomial time" (dropping the time bound collapses to `RecursiveIn`-style computability, not complexity);
- "deterministic" vs "nondeterministic" (conflating P^A and NP^A trivializes (a)).

---

## 6. Prior art and references

- **Source paper:** Baker, Gill, Solovay (1975), SIAM J. Comput. 4(4):431–442. *The informal source of truth.*
- **Textbook treatment (definitional source, per `UPSTREAM_TRACKING.md` §6):** Arora–Barak, *Computational Complexity: A Modern Approach*, §3 — the same source complexitylib follows.
- **Lecture-note constructions of both witnesses** (consulted in `docs/PRIOR_ART.md` search): Jin-Yi Cai, CS 810 Lecture 8 (cs.wisc.edu); Ronald de Haan, Complexity Lecture 5 (uva.nl); IISc Bangalore lec9.
- **Closest existing formalizations** (`docs/PRIOR_ART.md`, cross-assistant survey): Cook–Levin in Coq (Gäher & Kunze, ITP 2021) and Isabelle (Balbach, AFP) — both stop at NP-completeness; *neither* formalizes oracle machines or BGS. **No proof assistant formalizes relativization** — this is open ground (confirmed across Lean, Coq, Isabelle/AFP).
- **Mathlib substrate:** `RecursiveIn.lean` (oracle *computability*, unbounded) — usable as a reference for the totality question but not importable as the complexity substrate.
- **Recent theoretical refinement to watch (NOT part of this v1 statement):** arXiv:2601.09702 (Garcia, "Diagonalization Without Relativization," Jan 2026) argues a "semi-relativization" that claims to evade all three barriers. Per `docs/PRIOR_ART.md`, treat as a Rung 8 test case, *not* as established mathematics and *not* folded into this v1 statement.

---

## 7. What this spec does NOT yet resolve (open for the Lean author / Rung 2)

These are deliberately left open here; they are Rung 2 design tasks, not statement-fidelity questions:

1. The concrete Lean type of `Oracle` (function `ℕ → Bool`? `List σ → Bool`? depends on the base model's alphabet). Resolved when Rung 2's model lands.
2. Whether `P^A`/`NP^A` are stated as `Language → Prop` membership predicates or as bundled `Set Language` — follows the upstream `P`/`NP` choice (Gate 2 requires matching upstream).
3. The exact diagonalization *proof strategy* for B — that is proof-search work (Gate 7), gated by this frozen statement, not part of the statement.

These open items do not affect the frozen informal statement in §1; they affect only its Lean rendering, which Gate 4's read-back checks against §5.
