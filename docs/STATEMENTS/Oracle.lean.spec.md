# Design spec: `PleaNP/Computability/Oracle.lean`

**Rung:** 2 (the local, unblocked piece) — oracle machines are PleaNP's to build regardless of which upstream P/NP model lands (`docs/UPSTREAM_TRACKING.md` decision rule 2; `docs/STATEMENTS/Relativization.md` §2).
**Status:** Substrate confirmed (PARTIAL -- oracle machine only; P^A/NP^A blocked on step counting). Oracle.lean rendered, type-checks, hygiene-clean. See lean/PleaNP/Computability/Oracle.lean.

---

## 1. Why this file exists and what it is *not*

`Oracle.lean` defines the **oracle-machine substrate** that relativization (Baker–Gill–Solovay) requires. It is the single highest-leverage unblocked piece of the project: `docs/STATEMENTS/Relativization.md` cannot be rendered into Lean until this file exists, and this file does *not* depend on the contested upstream P/NP choice (it composes with whichever model lands).

**What this file is *not*:** it is *not* a proof, *not* a barrier theorem, and *not* a definition of `P`/`NP` (those are upstream, per DEC-003). It is the *machinery* — the oracle type, the oracle machine, and the step-counting that lets us later define `P^A`/`NP^A`. Proving anything about oracles (the BGS existence result) is Rung 3 work and lives in `PleaNP/Barriers/Relativization.lean`, gated by the frozen statement spec.

---

## 2. The four objects `Oracle.lean` must define

### 2.1 The oracle type

An oracle is a **total function from strings (or bitstrings) to a yes/no answer**. "Total" is the load-bearing word: it answers *every* possible query, never "I don't know." This is the distinction from Mathlib's `RecursiveIn.lean` (which operates over *partial* functions — the enumeration-degree notion, per `docs/PRIOR_ART.md` §1, the Park/Carneiro Zulip discussion).

**Logical shape (not Lean — the local agent renders):**
- An `Oracle` is parameterized by the base model's string/query type. Concretely: a total function from the query space (e.g. `List Bool` or `ℕ`-encoded strings) to `Bool` (or `{yes, no}`).
- Equivalently, an oracle *is* a language (a set of strings) — the set it answers "yes" to. Both presentations are standard; the local agent picks the one that composes cleanly with the chosen upstream machine model, and records the choice.

**Acceptance criteria:**
- The oracle is *total by type* — the function's codomain is `Bool` (a total space), not `Option Bool` or `Part Bool`. This is the structural enforcement of totality. An `Option`-valued oracle would be a *different* object (a partial oracle, the `RecursiveIn` notion) and would make the BGS statement a different (and in clause (a)'s case trivial) theorem — a Gate 5 (non-triviality) concern.
- The oracle is **not** required to be *computable* at the type level — an oracle is a mathematical function that may or may not be decidable. (The BGS witnesses A and B happen to be computable, but that's a *hypothesis* on the witness, stated in the theorem, not a constraint on the oracle *type*. See `Relativization.md` §3: the recursiveness is a hypothesis on the existentially-quantified oracle.)

### 2.2 The oracle machine (TM + oracle tape + query transition)

An oracle machine is a Turing machine (of whatever base model lands upstream) with one added piece of hardware: a dedicated **oracle tape** and a **query state**. When the machine enters the query state:
1. the string currently on the oracle tape is treated as a query `q`;
2. the oracle `A` (fixed for this machine) is consulted, yielding `A(q) ∈ Bool`;
3. the answer is written to a designated cell (or the machine transitions to one of two states based on the answer);
4. **this entire step counts as one step** in the time complexity measure.

**Logical shape:**
- Parameterize the base machine model (the upstream `TM1` or `FinTM0` or Reitwiessner multi-tape) by an oracle `A : Oracle`.
- Add the oracle tape as an extra tape (if the base model is multi-tape) or a reserved segment (if single-tape). The local agent picks the composition that matches the landed upstream model — this is a Rung 2 design task, not a statement-fidelity question.
- The query transition is a single transition that consumes the oracle tape's content and produces the answer. The crucial modeling choice: the oracle is **not** simulated (we do not run A's decider); the transition *stipulates* the answer. This is the "one-step, for free" idealization — it is a cost-model definition, not a claim that A is physically computable in one step (see the "is the oracle a fantasy" discussion: it's a stipulated accounting rule, like a frictionless plane).

**Acceptance criteria:**
- The query transition is a *single* step in the step-counter — not simulated, not amortized. If the local agent's rendering simulates the oracle (runs A's decider and counts those steps), that is a *different* model (it would make `P^A` depend on A's actual complexity, which collapses the barrier). The hygiene/model-consistency check must verify the query is one step.
- The oracle `A` is *fixed* for a given machine — the machine may query `A` but not change it or query a different oracle mid-computation. (Parameterize the machine type by `A`; `A` is not a tape the machine can write.)

### 2.3 Step counting (the complexity layer)

This is the piece that turns "oracle machine" into "oracle *complexity*." Mathlib's `RecursiveIn` has no step counting — it's unbounded-time computability. PleaNP must define a step-counting measure on oracle machines, analogous to the upstream effort's `runN` (#35366) or `EvalsToInTime` (#33132), but extended to count oracle queries as single steps.

**Logical shape:**
- A `runN`-style (fuel-based) or relational `EvalsToInTime`-style measure on oracle machines, where each oracle query consumes 1 unit of fuel/time.
- This is the substrate on which `P^A` and `NP^A` will later be defined (in `OracleComplexity.lean`, a separate file): `P^A` = languages decidable by a deterministic oracle machine for `A` in `poly(n)` steps; `NP^A` = the nondeterministic analogue.

**Acceptance criteria:**
- Oracle queries count as exactly 1 step, consistent with §2.2.
- The measure is *compatible* with whichever upstream step-counting measure lands — i.e., a non-oracle machine's step count under PleaNP's measure should agree with the upstream `runN`/`EvalsToInTime` on the base model. (Otherwise `P^∅` — P relative to the empty oracle — would not equal upstream `P`, breaking Gate 2 model-consistency.) The local agent should verify this compatibility once the upstream model is chosen.

### 2.4 The `P^A` / `NP^A` complexity classes (likely a separate file)

**Scope note:** The actual `P^A`/`NP^A` definitions probably belong in `PleaNP/Computability/OracleComplexity.lean`, not `Oracle.lean` itself — `Oracle.lean` provides the machine + step-counting substrate, and the *classes* are built on top. The local agent may split or combine these; the spec only requires that the split is recorded and the dependency direction is clear (oracle machine → step counting → complexity classes). These classes are what `Relativization.md` §2 lists as "PleaNP-local — the time-complexity layer."

**Acceptance criteria for the classes (when built):**
- `P^A` and `NP^A` are *language classes* (sets of languages), so that `P^A = NP^A` is extensional set equality — a Gate 2 check item from `Relativization.md` §3.
- They are parameterized by the oracle `A` (a `variable [Oracle A]` or explicit parameter), not by a constructed oracle.
- `P^∅` (empty oracle) reduces to upstream `P` — the compatibility check from §2.3.

---

## 3. The totality discipline (the one thing that must not be gotten wrong)

This is the single most important acceptance criterion, because it's where "build it wrong → fake success" (`FAILURE_AUDIT.md` Pattern A) is most likely for this file.

**The rule:** PleaNP's oracle is *total* by construction. It must not reuse Mathlib's `RecursiveIn` / `TuringReducible` types as-is, because those are the *partial* (enumeration-degree) notion — `docs/PRIOR_ART.md` §1 documents this defect (Park, Feb 2026; Carneiro's response). Using the partial notion would make the oracle *not* the BGS oracle, and any "P^A = NP^A" proof against it would be a proof of a different (and weaker) statement.

**Structural enforcement:** totality is enforced at the *type level* — the oracle's codomain is `Bool`, not `Part Bool` or `Option Bool`. The local agent should not define the oracle as "a partial function that answers when defined," because that reintroduces the partial notion. If the chosen upstream model forces a partial representation somewhere, the local agent must lift it to total via the standard `Part.toOption`/`Option.toBool`-style coercion and *document* that lift — it's the kind of subtlety Gate 4 (read-back) exists to catch.

**Gate mapping for this file specifically:**
- Gate 2 (model-consistency): the oracle type is `PleaNP.Oracles.Oracle`, not a local alias of `RecursiveIn` or `TuringReducible`. The linter/human checks the import.
- Gate 4 (read-back): an auto-generated read-back of the `Oracle` definition must produce "a total function from strings to yes/no" — if it reads "a partial function..." or "a function that may not answer," the rendering is wrong.
- Gate 6 (hygiene): `Oracle.lean` itself should have zero `sorry` (it's definitions, not proofs) — run `python3 tooling/gates/hygiene_scan.py --prove-stage lean/PleaNP/Computability/` and expect a clean pass.

---

## 4. Composition with the upstream model (the open design questions)

These are deliberately left open; they are Rung 2 design tasks the local agent resolves once a base model is chosen (or once the complexitylib reconciliation verdict is in — see `docs/UPSTREAM_TRACKING.md` §6):

1. **Which base model?** If complexitylib reconciles (local agent step 1), use its multi-tape Arora–Barak model. If a Mathlib effort lands first (#35366 `TM1`+`runN` is the strong candidate), extend that. If Reitwiessner's multi-tape lands, consider it (it's the only one with space bounds, though relativization is time-bounded). The choice is recorded in `docs/decisions/LOG.md` per decision rule 4.
2. **Single-tape vs multi-tape oracle tape.** A multi-tape base model makes the oracle tape a natural extra tape; a single-tape model requires reserving a segment. The local agent picks the composition that's cleanest for the landed model.
3. **Query encoding.** How queries are written to the oracle tape (bitstrings? Gödel-encoded naturals?) follows the base model's alphabet/encoding. The unary-alphabet trap (`PRIOR_ART.md` §5: "with a unary alphabet, P=NP") is a Gate 2 concern — the encoding must not trivialize the complexity classes.

These do not affect the *logical shape* in §2; they affect only the Lean rendering, which the local agent validates with `lake build` and which Gate 4 checks against the read-back.

---

## 5. What "done" looks like for `Oracle.lean`

Per the `LOCAL_AGENT_WORKFLOW.md` status convention, this file progresses:
- **Draft spec** (this document) →
- **Substrate confirmed** (the base model is chosen; `lake build` on the dependency succeeds) →
- **Rendered, type-checks** (`Oracle.lean` compiles; definitions are `sorry`-free) →
- **Gates 2/4/6 passed** (totality verified at type level; read-back matches §2.1; hygiene scan clean) →
- **Frozen** (the oracle-machine substrate is fixed; `Relativization.lean` may now be built against it).

At that point `docs/STATEMENTS/Relativization.md`'s §2 dependency "Oracle machines — PleaNP-local" flips from *Unblocked* to *Done*, and the relativization statement can be rendered (Step 1 of its own workflow), still blocked on the *upstream* `P`/`NP` for the final statement.

---

## 6. Prior art and references

- **Mathlib substrate to compose with:** `Mathlib/Computability/PostTuringMachine.lean` (TM0/TM1/TM2, Carneiro 2018), `Mathlib/Computability/RecursiveIn.lean` (Duve/Roth 2025 — the partial oracle-computability notion, *not* to be reused as the oracle type, per §3).
- **The totality defect (why not to reuse `RecursiveIn`):** `docs/PRIOR_ART.md` §1 (Edwin Park / Mario Carneiro / Tanner Duve Zulip discussion, Feb 2026).
- **No existing oracle-machine formalization:** `docs/PRIOR_ART.md` (cross-assistant survey) confirms no proof assistant has time-bounded oracle machines — this file is genuinely novel substrate.
- **complexitylib (potential shortcut for the base model, not the oracle):** `docs/UPSTREAM_TRACKING.md` §6 — has multi-tape TMs + step counting but *not* oracle machines (its roadmap lists oracle access as unfinished). So even if complexitylib is imported, `Oracle.lean` is still PleaNP's to write.
- **The BGS statement this substrate serves:** `docs/STATEMENTS/Relativization.md`.
