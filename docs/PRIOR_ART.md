# Prior art: Lean-community discussions and related formalizations

**Purpose.** Record what the Lean community (Zulip archive, project listings) and adjacent formalization efforts have already done or discussed around computational complexity, oracle machines, and the three barriers. This grounds PleaNP's novelty claims and surfaces reusable substrate.

Searched: the Mathlib4 Zulip archive at `https://leanprover-community.github.io/archive/stream/287929-mathlib4/` (and adjacent streams) for: oracle machines, Baker-Gill-Solovay, natural proofs, algebrization, complexity barriers, complexitylib. Last searched: 2026-08-18.

---

## Headline finding

**The three barriers are absent from the Lean Zulip archive.** Searches for "Baker-Gill-Solovay", "natural proofs", "Razborov-Rudich", "algebrization", and "Aaronson-Wigderson" across the archive (`leanprover-community.github.io`) return **no** threads discussing them as formalization targets. The only Zulip "oracle" discussions are (a) the `linarith` tactic's certificate *oracle* (unrelated) and (b) decidability-oracle thought experiments (Damiano Testa / Mario Carneiro, new-members stream, Mar 2021 — about noncomputable reals, not complexity).

This corroborates the gap audit's central claim: **the barrier theorems are open ground in every proof assistant, in every model.** PleaNP's core contribution is genuinely novel.

---

## Prior art found

### 1. Oracle Computability Theory (mathlib4 stream, Jan–Feb 2026)

**Thread:** `stream/287929-mathlib4/topic/Oracle.20Computability.20Theory.html` (39 messages, latest Feb 28 2026).

- **Edwin Park** formalized the Kleene-Post theorem and degree-theoretic foundations in `https://github.com/hyeoniuwu/CiL` (Lean, toolchain `v4.33.0-rc2`, no license, 2 stars). Includes the KP54 capstone proof. Proposes merging into Mathlib.
- **Material finding for PleaNP — a defect in Mathlib's `TuringReducible`/`TuringDegree`:** Park (Feb 17 2026) reports that Mathlib's current `TuringReducible` is defined over *partial functions*, which actually yields **enumeration degrees**, not true Turing degrees (which require *total*-function oracles). Park fixed it in CiL's `Oracle.lean`.
- **Tanner Duve** (author of Mathlib's `RecursiveIn.lean`, tracked in `UPSTREAM_TRACKING.md`) responded: the current definition is a "strict generalization" and the issue is "misnaming rather than definitions being incorrect"; proposed renaming `TuringReducible` → `PartialReducible` and recovering the standard notion by lifting total functions via `Part.some`.
- **Mario Carneiro** (Feb 27 2026) weighed in: keep the general (partial) definition, since "getting the equivalent notion is much harder without it"; totality is "the responsibility of whatever derived notion writes a quantification over those functions."
- **Implication for PleaNP:** PleaNP's oracle-machine work should be aware that Mathlib's `RecursiveIn`/`TuringReducible` is the *partial* (enumeration-degree) notion. For relativization (`P^A`, `NP^A`), oracles are total by definition (they answer in one step), so PleaNP's oracle machines will compose with *total* oracles regardless of the Mathlib partial-general definition. No conflict — but the naming/totality distinction must be respected. **No rung scope change.**

### 2. Complexity theory in Lean — "Is there code for X?" (Jul 2021)

**Thread:** `stream/217875-Is-there-code-for-X%3F/topic/Complexity.20theory.html`.

- **Mario Carneiro** (Jul 13 2021): the existing computability material was "written with an eye for complexity theory" (future work in the arXiv paper), "but not much in that direction has landed yet." Notes **Pim Spelier has some unmerged complexity theory work on P and NP** (link dead).
- **Martin Dvořák:** planning a PhD on formalizing complexity theory in Lean.
- **Implication:** confirms the gap audit — as of 2021, Mathlib had computability but essentially no complexity. Pim Spelier's unmerged P/NP work is the earliest such effort known; its status is unverified (predates the tracked #35366 / #33132 efforts in `UPSTREAM_TRACKING.md`).

### 3. Computational Complexity Theory (general stream, Dec 2021)

**Thread:** `stream/113488-general/topic/Computational.20Complexity.20Theory.html`.

- Multi-month discussion (Martin Dvořák, Bolton Bailey, Mario Carneiro, Arthur Paulino, Dima Pasechnik) on a roadmap for complexity in Lean.
- Discusses the **Arora-Barak book** as a definitional source (same source complexitylib uses — see `UPSTREAM_TRACKING.md` §6).
- Debates the **λ-calculus L model** (Forster/Kunze Coq route) vs Turing machines; concludes the λ-calculus route is more ergonomic ("I don't even want to imagine a formalization using turing machines" — unnamed). A concrete 11-step roadmap is sketched (define P/NP/reductions/NP-completeness in L, Cook-Levin).
- **Dima Pasechnik** notes the "1st order reductions" alternative (descriptive complexity) — the Senellart axis tracked in `GAP_AUDIT.md` §9.
- **Implication:** corroborates the upstream-tracking finding that the computational-model choice is contested; the λ-calculus fallback is a live community option, not just a Coq precedent. **No rung scope change** — Rung 2 already tracks this as upstream-blocked.

### 4. Ph.D. on formalizing complexity classes (general stream, Aug 2021)

**Thread:** `stream/113488-general/topic/Ph.2ED.2E.20on.20formalizing.20complexity.20classes.html`.

- Martin Dvořák seeks PhD advice; Mario Carneiro and Johan Commelin caution that formalizing complexity is library-grinding ("80% of your time writing libraries that prove stuff covered in the first two introductory courses") and that some advisors don't value formalization as research.
- **Implication:** methodological, not technical. Relevant to PleaNP's positioning — the barrier-library framing (meta-theorems, not class definitions) is precisely the high-value framing that avoids the "trivial class library" trap.

### 5. Hunter Monroe PR #8931 — P/NP definitions without theorems (Gödel thread, Dec 2023)

**Thread:** `stream/113488-general/topic/G.C3.B6del's.20first.20incompleteness.20theorem.html`.

- **Hunter Monroe** proposed Mathlib PR #8931 with definitions of P, NP, NP-completeness, and poly-time reductions, *without theorems*. Stalled on the **encoding/alphabet question**: "With a unary alphabet, P=NP... With a sufficiently inefficient encoding, anything computable is in P."
- **Mario Carneiro** points to `Primcodable` as the canonical answer to the encoding problem.
- **Implication for PleaNP — directly relevant to Gate 2 (model-consistency):** the unary-alphabet trap ("if the encoding is unary, P=NP") is a concrete instance of the statement-fidelity failure mode the integrity architecture is designed to prevent. PleaNP's model-consistency gate must pin the encoding (via upstream `Primcodable`) to avoid this. **No rung scope change**, but it sharpens Gate 2's linter requirement.

### 6. Claimed NP = PSPACE formalization (general stream, "Lean in the wild", Aug 2019)

**Thread:** `stream/113488-general/topic/Lean.20in.20the.20wild.html`.

- **Floris van Doorn** (Aug 5 2019): reports an FOM mailing-list thread where someone claims to be formalizing a proof that NP = PSPACE in Lean; notes the claim is "widely suspected to be false."
- **Implication for PleaNP:** a textbook instance of failure-audit Pattern A (formalizing a statement that is almost certainly false, trusting the formalization as authority). Reinforces the necessity of the statement-fidelity gates. **No rung scope change** — it is evidence *for* the existing architecture, not against the rungs.

---

## Related formalization efforts (from Lean project listings)

### CSLib — The Lean Computer Science Library

- Listed at `leanprover-community.github.io/lean_projects.html` (★ 640). A general CS library for Lean, distinct from complexity theory per se. **Tanner Duve** (Oracle Computability thread) noted oracle/degree theory is "firmly within mathematics" and "isn't very related to the kind of cs theory that would go into cslib."
- **PleaNP stance:** not a complexity substrate. Monitor for incidental overlap only.

### Edwin Park's CiL

- `https://github.com/hyeoniuwu/CiL` — computability and degree theory (Kleene-Post, Turing degrees). Lean, toolchain `v4.33.0-rc2`, **no license** (blocks import until added), 2 stars.
- **PleaNP stance:** closest existing work to PleaNP's oracle substrate, but it's *computability* (unbounded) not *complexity* (bounded). Its corrected `TuringReducible` definition is a useful reference for the totality question. Not importable (no license, and it's degree theory, not barriers).

---

## What was NOT found

- **No formalization of any of the three barriers** (relativization, natural proofs, algebrization) in Lean, Coq, Isabelle, or any other proof assistant surfaced via the Zulip archive.
- **No prior discussion of "complexitylib" by name** in the archive (it's a newer project; the Zulip search did not index a discussion thread for it).
- **No prior discussion of oracle *machines*** (TM + oracle tape + time bound) — only oracle *computability* (unbounded, recursion-theoretic).

---

## Rung-scope conflicts — none requiring rewrite

Per the instruction, conflicts that would materially change a rung's scope are flagged here. **None found.** The prior art is consistent with the existing rung ladder:

- The `RecursiveIn` totality defect (§1) and the unary-alphabet trap (§5) sharpen *gate requirements* (Gate 2 model-consistency) and the *oracle-machine design note* in `GAP_AUDIT.md` §3, but they do not change any rung's goal or ordering.
- The λ-calculus model debate (§3) is already captured by Rung 2's "blocked on upstream, evaluate synthetic approach as fallback" stance.
- The failure-mode instances (§5, §6) are evidence *for* the integrity architecture (Rung 6 / cross-cutting gates), not changes to it.

No rungs rewritten.
