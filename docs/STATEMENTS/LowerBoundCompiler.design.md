# Lower-Bound Compiler design — Williams transfer as a Lean elaborator (#80)

**Status:** working-design note for the Rung-8 **Lower-Bound Compiler**
(`docs/ROADMAP.md` Rung 8, DEC-012 scope expansion). Written 2026-09-13
(run=20260913-2216-8053) during the #80 claim — Pass 1 of #80 (the design
note; Pass 2 is the elaborator skeleton). **NOT a frozen proof spec and
NOT a proof** — a design that seeds the elaborator work, modeled on
`Algebrization.design.md` (#68) and `NaturalProofs.design.md` (#67).

**Companion docs:** `docs/ROADMAP.md` Rung 8 (the scope-expansion sketch);
`#76` (the Williams-transfer umbrella whose formalization this compiler
automates); `#88`/#89/#90/#91 (the transfer's four passes); `#71` (the
Rung-4 circuit substrate the compiler lays on top of); `#73` (barrier
classifications).

---

## 1. What the compiler is

The Lower-Bound Compiler is a Lean **elaborator command** (sketched as
`#lower_bound_compile`) that mechanizes **Williams' transfer theorem**:

> A *nontrivial* CircuitSAT algorithm for a circuit class C ⟹
> **NEXP ⊄ C.**

"*Nontrivial*" is the load-bearing quantifier: the CircuitSAT algorithm
must run in time **sub-exponential** in the number of input wires —
`2^{n^{o(1)}}` — where `n` is the number of gates/wires. In this sub-
exponential regime the whole panoply of classical lower-bound barriers
fails: the resulting lower bound `NEXP ⊄ C` is the *one known*
**non-relativizing, non-natural, non-algebrizing** lower bound (the point
of `docs/ROADMAP.md` Rung 4 and #73, and the reason Williams-type
arguments escape the BGS/natural-proofs/algebrization barriers).

The compiler turns the *proof-search* problem ("prove NEXP ⊄ ACC⁰") into
an *input-contract* problem: **feed it a verified algorithm + verified
runtime bound, and it emits the lower bound with the dependency closure
attaching the runtime.** The verified runtime is what the emitted theorem
carries — the elaborator's output is only as strong as its input contract
is honest (Gate 2/4 discipline: no asserted runtime, no compiled-vacuous
lower bound).

---

## 2. The input contract (the elaborator's typed interface)

The elaborator consumes a single structured input — a *verified
CircuitSAT witness* — built on the #71 substrate:
`lean/PleaNP/Circuits/Basic.lean` (circuit-family type + size/depth
functions) and the #88 statement-freeze anchors (`NEXP`, `ACC⁰`,
`CircuitSAT` decision problem).

### Contract fields (all Lean declarations — the input is a *proof* of
each, not data)

| Field | Lean obligation | Source / where it lands |
|---|---|---|
| **The target class** `C` | the circuit class under which SAT is decided; for the canonical target, `C = ACC⁰` (from the #88 freeze) | `PleaNP.Circuits` (`ACC0` module — #72 substrate work) |
| **The SAT decider** `sat_c : Circuit → Bool` | a deterministic algorithm deciding `CircuitSAT` for `C`-circuits | #89 Pass 1 (the cost/step-counting model + `acc0Sat` skeleton) |
| **Correctness** `∀ C, sat_c C = true ↔ C ∈ CircuitSAT` (or the #88-frozen form) | verified in Lean | #89 Pass 1/2 |
| **Nontriviality** `∃ c, ∀ C, time (sat_c C) ≤ 2^{n^{o(1)}}` | the *verified runtime bound* — a step-counting bound on the #71 substrate's cost model, **not asserted** | #89 Pass 3 (the hardest lemma) |
| **Size measure** `n` | the circuit's size (wire/gate count) from the #71 `CircuitFamily.size` | #71 / #88 |

The transfer's precondition is exactly this tuple. The elaborator's
signature is:

```
#lower_bound_compile sat_c
  (hcorrect : ∀ C, sat_c C = true ↔ C ∈ CircuitSAT)
  (hnt : ∃ c, ∀ C, time (sat_c C) ≤ 2^(size C)^(o(1)))
  ... emits ... NEXP ⊄ C
```

### Anti-requirements (what the contract must NOT accept)

- **No asserted runtime.** A `sorry`-carried `hnt` is a rejected input
  (Gate 6 catches it at the emitted claim; `#barrier_check` warns).
- **No vacuous class.** `C = ∅` or a degenerate class where `NEXP ⊄ C`
  is trivially true is a rejected emission (vacuity scan / Gate 5).
- **No melting of the size measure.** The runtime bound and the lower
  bound must use the *same* `n` (`CircuitFamily.size`), or the transfer's
  exponent arithmetic is silent nonsense. This is the compiler's own
  dependency-closure check.

---

## 3. What the elaborator emits (the theorem transformer)

Given a valid contract, the elaborator emits:

```
NEXP ⊄ C           -- class strict non-containment
```

with a **dependency closure** that attaches:
1. the verified `sat_c` + correctness proof (the CircuitSAT side),
2. the verified runtime bound `hnt` (the nontriviality side),
3. the #88 frozen anchors it references (`NEXP`, `ACC⁰`, `CircuitSAT`),
4. the #71 substrate definitions (`Circuit`, `size`, step-count model).

The emitted claim is a *theorem* whose proof term the elaborator
synthesizes from the transfer theorem (Williams 2011) instantiated with
the contract — the transfer being the #90 pass's theorem. The
`#barrier_check` on emitted claims: expected verdict **Inconclusive** for
the *meta-claim* (a lower bound that is itself non-algebrizing is not
algebrization-blocked), consistent with the Rung-5 verdict discipline.

---

## 4. Decomposition / dependency ordering

The compiler is the *automation* of the #76 transfer; everything it
consumes is already sequenced by #76's pass chain:

```
#71 circuit substrate (landed Pass 1-2)
  └─ #88 statement freeze (NEXP / ACC⁰ / CircuitSAT)     → Pass 1 of #76
       └─ #89 CircuitSAT algorithm + verified runtime     → Pass 2 of #76
            └─ #90 transfer theorem (CircuitSAT ⟹ NEXP ⊄ C) → Pass 3 of #76
                 └─ #91 assembly + classification (#73)    → Pass 4 of #76
                      └─ THIS COMPILER (#80): the elaborator command
                           └─ Pass 2 of #80: `#lower_bound_compile`
                              skeleton + one example emission compiles
```

Non-blocking status (DEC-012): the compiler is the widest eventual
force-multiplier but explicitly does **not** block earlier rungs. #80
Pass 2 (the skeleton) is claimable once #90 (the transfer theorem) lands,
because the skeleton's emitted theorem needs the transfer to build the
proof term.

---

## 5. Pass 1 / Pass 2 split (this issue)

- **Pass 1 — this design note** (docs-only, landed in this commit):
  the input contract (above) + the emission contract (§3). Establishes
  *which* verified inputs make the compiler honest.
- **Pass 2 — `#lower_bound_compile` skeleton + one example emission**:
  the elaborator command (a `syntax`/elab command in
  `lean/PleaNP/Circuits/` or a `Mathlib.Lean`-hosted elaboration),
  typechecking the contract fields and synthesizing the emission the
  transfer theorem gives. DoD: build green on the elaborator module;
  `#barrier_check` on the emitted claim. Blocked by #90 (the transfer
  theorem, #76 Pass 3).

If #90 is delayed, Pass 2 may land a *stub* that typechecks the contract
shapes and emits a placeholder emission only after the transfer exists —
the honest intermediate is the stub-with-follow-up, not a compiled-with-
sorry emission.

---

_Last updated: 2026-09-13 (issue #80 Pass 1). The elaborator skeleton
follows in Pass 2 once the #76 transfer theorem (#90) lands._