# Spec: CI hygiene enforcement (sorry-as-error + linters)

**Rung:** Cross-cutting (integrity tooling). Makes Gate 6 (hygiene) and the lint floor *enforced* rather than aspirational.
**Status:** Executed (2026-08-18). Per-file `set_option warningAsError true` pragmas added to all PleaNP .lean files. CI workflow created (.github/workflows/ci.yml). `lake exe lint` not available in v4.31.0; #lint test file is the documented fallback (not yet wired). See DEC-009.

---

## 1. What this spec is and why it exists

The hygiene scanner (`tooling/gates/hygiene_scan.py`, Gate 6 Tier 1) catches `sorry`/`admit`/custom-`axiom` via grep. But a grep pass is only as good as *running it*, and a local build is only as honest as its warning policy. Right now:
- `lean/lakefile.lean` has **no** `warningAsError` / sorry-as-error config (verified: the `package` block has no `moreLeanArgs`).
- There is **no CI** (verified: `.github/workflows/` does not exist).
- `sorry` currently produces a *warning*, not an error — a `sorry`-laden file builds green.

This spec defines how to make hygiene *enforced*: `sorry` becomes a hard build failure, Mathlib's linters run on every build, and CI gates merges on all of it plus the hygiene scanner. This is the "stricter compiler for this type of proof writing" lever — and the honest limit of it: it catches the *mechanical* failures (sorry, axioms, lint), not the *semantic* ones (wrong statement, vacuity, collusion) that Gates 1–5 exist for. See `docs/ARCHITECTURE.md` and `docs/STATEMENTS/LOCAL_AGENT_WORKFLOW.md` for the split.

**What this spec is *not*:** it is not Gate 6 complete on its own. Gate 6 Tier 2 (`#print axioms`, `tooling/gates/hygiene_axioms.lean`) catches sorry-smuggled-via-meta, which no compiler flag or grep sees. This spec enforces Tier 1 + lints; Tier 2 remains the local agent's separate job. "CI green" is not "Gate 6 passed" until Tier 2 also runs.

---

## 2. The three levers (what the local agent configures)

### 2.1 sorry-as-error (the kernel-side floor)

Make `sorry` (and warnings generally) hard errors. The modern mechanism is a `package`-level `moreLeanArgs` in `lean/lakefile.lean`:

**Logical shape (the local agent renders the exact syntax for v4.31.0):**
- Add to the `package «PleaNP» where` block a `moreLeanArgs` setting that turns warnings into errors, e.g. `moreLeanArgs := #["-D warningAsError=true"]` (the precise flag/option name for v4.31.0 is to be confirmed by the local agent against `lake` docs — `warningAsError` is the standard Lean option).
- The intended effect: any `sorry` in a PleaNP file fails `lake build`.

**Acceptance criterion:** a throwaway file containing `example : True := by sorry` must cause `lake build` to *fail*; deleting the file must restore a green build. Record the exact config used.

### 2.2 Mathlib's linter suite

Run Mathlib's linters (style, naming, docstrings, unused args, etc.) on every build/CI.

**Logical shape:**
- Determine, against Mathlib v4.31.0, whether `lake exe lint` is exposed (Mathlib ships a linter executable in some versions) or whether the path is a `#lint` call in a test file. Report which works.
- Make the lint mandatory: either CI runs `lake exe lint`, or a `lean/tests/Lint.lean` file runs `#lint` against the library and the `tests` exe fails on lint errors.

**Acceptance criterion:** a deliberate style violation (e.g. an undocumented, mis-named declaration) is caught and fails the build/CI; fixing it restores green. Record the chosen path (`lake exe lint` vs `#lint` test file) and why.

### 2.3 CI as the enforcement layer

A `.github/workflows/ci.yml` that gates merges on hygiene + lint + build. This is the structural enforcement — local builds can be lax, but a PR doesn't merge unless CI is green.

**Logical shape (the local agent renders the YAML for the GitHub Actions runner):**
- Checkout.
- Set up the Lean toolchain (`leanprover/lean-toolchain` action, pinned to `leanprover/lean4:v4.31.0` per `lean/lean-toolchain`).
- Run `lake build` (which now fails on sorry, per §2.1).
- Run the Mathlib linter (per §2.2).
- Run `python3 tooling/gates/hygiene_scan.py --prove-stage lean/PleaNP` (the Gate 6 Tier 1 scanner, in `--prove-stage` mode so any `sorry` is a violation).
- The workflow fails on any non-zero exit from any step.

**Acceptance criterion:** a PR adding a `sorry` to a PleaNP file fails CI; a PR without one passes. The CI must run on `main` (the default branch — note: the repo default is `main`, not `master`; verify `.github/workflows/ci.yml` triggers on `main`).

---

## 3. The critical caveat — do not make Mathlib's warnings ours

`warningAsError=true` as a *global* flag risks failing the build on *Mathlib's* warnings (Mathlib under v4.31.0 may emit warnings that are Mathlib's concern, not ours). The local agent must verify the flag scopes to **PleaNP's files only**, not Mathlib's build.

**Primary path:** package-level `moreLeanArgs` — confirm it applies to PleaNP's compilation, not to the `require mathlib` dependency build. If `lake` scopes it correctly, use it.

**Fallback path:** if the package flag cannot be scoped (i.e. it breaks Mathlib's build), do *not* use the global flag. Instead, add `set_option warningAsError true` at the top of each PleaNP `.lean` file (a per-file pragma). This is more verbose but unambiguous about scope. Report which path was taken and why.

**Acceptance criterion for this caveat specifically:** the final config must make PleaNP's `sorry` fail the build *without* making Mathlib's warnings fail it. The local agent's report must state which path (package flag vs per-file pragma) achieved this.

---

## 4. What "done" looks like

Per the `LOCAL_AGENT_WORKFLOW.md` status convention:
- `lean/lakefile.lean` (or per-file pragmas) configured so `sorry` is a hard error for PleaNP files.
- Lint mechanism chosen and wired (`lake exe lint` or `#lint` test).
- `.github/workflows/ci.yml` created, running build + lint + hygiene scanner; verified to fail on a deliberately-sorry'd PR and pass on a clean one.
- A new `DEC-0XX` in `docs/decisions/LOG.md` (scope: build/CI hygiene enforcement) recording the chosen config (package flag vs per-file pragma; `lake exe lint` vs `#lint`), with rationale. This is a genuine architectural decision (it changes how the build behaves for every contributor), so it *does* belong in the decision log — unlike routine doc work.
- `tooling/gates/README.md` updated to note Gate 6 Tier 1 is now enforced in CI (and that Tier 2 / `#print axioms` is still required for "Gate 6 complete").

---

## 5. Scope honesty (what this does NOT enforce)

- **Does not catch sorry-smuggled-via-meta.** A custom tactic that internally calls `sorry` shows no `sorry` token at the call site — invisible to both the grep scanner and `warningAsError` (which fires on the *sorry*, wherever it is, but only if that sorry is in a file that's compiled... the meta-smuggling case is subtle and is exactly why Tier 2's `#print axioms` exists). This spec enforces Tier 1 + lints; Tier 2 remains separate.
- **Does not catch wrong/vacuous statements.** A compiling, sorry-free proof of the *wrong* statement passes this CI green. Gates 2–5 (model-consistency, statement-fidelity, read-back, non-triviality) are not compiler-enforceable and are not in this spec. "CI green" is a necessary, not sufficient, integrity condition.
- **Does not run Lean's kernel on proofs the AI produces** beyond what `lake build` already does — the kernel is already the strictest proof checker; this spec just makes its *warnings* fatal and adds lints.

---

## 6. References

- `tooling/gates/hygiene_scan.py` — the Gate 6 Tier 1 scanner this CI invokes.
- `tooling/gates/hygiene_axioms.lean` — the Gate 6 Tier 2 spec (the local agent's separate job; this CI spec does not replace it).
- `tooling/gates/README.md` — the two-tier Gate 6 split.
- `docs/ARCHITECTURE.md` — the full gate pipeline; this spec operationalizes the *mechanical* subset (Gate 6 + lint floor).
- complexitylib's `AxiomGuard` (`docs/UPSTREAM_TRACKING.md` §6) — prior art for the axiom-tracking half.
