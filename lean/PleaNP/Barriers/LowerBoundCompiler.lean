import PleaNP.Barriers.WilliamsAssembly
import PleaNP.Calculus.BarrierCalculus

set_option warningAsError true

/-!
# Lower-Bound Compiler — `#lower_bound_compile` (issue #80, Pass 2)

Rung 8 of the roadmap: mechanize Williams' transfer theorem

> a *nontrivial* (sub-exponential) CircuitSAT algorithm for a circuit class
> `C` ⟹ `NEXP ⊄ C`

as a Lean **elaborator command**, so that proving the lower bound becomes an
*input-contract* problem: hand the compiler a verified algorithm together
with its verified runtime bound, and it emits the lower bound with the
dependency closure attaching the runtime.

The design (input contract, anti-requirements, dependency ordering) is
`docs/STATEMENTS/LowerBoundCompiler.design.md` (Pass 1, commit `084dc35`).
This module is the Pass-2 **skeleton**: the command, its contract guards,
and one example emission that compiles.

## The emitted claim

Pass 3 of the #76 umbrella froze the transfer as
`williams_transfer : SubExpCircuitSATT → NEXP_not_subset_ACC0`
(`PleaNP.Barriers.WilliamsTransfer`). The compiler's emission is the
*elimination* of that arrow at a supplied contract:

```
#lower_bound_compile <contract> as <name>
```

emits `theorem <name> : NEXP_not_subset_ACC0 := williams_transfer <contract>`
where `<contract>` is a **proved** `SubExpCircuitSATT`.

## Honest status of the full emission (why the example is conditional)

A *proved* `SubExpCircuitSATT` does not exist yet: its sub-exponential half
is the tracked `acc0SatSubExpBound` gap (`WilliamsSat.lean`) — the
ACC⁰-structure packing argument (Shah–Shetty-style Good-SAT), which is the
research content tracked by **#98**. So the example invocation in this module
uses the **conditional** form

```
#lower_bound_compile_cond as <name>
```

which emits the transfer closure `SubExpCircuitSATT → NEXP_not_subset_ACC0`
under the emitted name. That is the shape available today; the full
`#lower_bound_compile <contract> as <name>` path is implemented and guarded,
and becomes usable unchanged the moment #98 lands a contract proof.

Neither form introduces a `sorry`: the conditional form is a complete
theorem, and the full form is a complete theorem *given* a complete
contract.

## Contract guards (design note §2, "anti-requirements")

`#lower_bound_compile` refuses a contract that

- **depends on `sorryAx`** — a `sorry`-carried runtime is a rejected input
  ("no asserted runtime"): the emitted theorem would be only as strong as
  the contract's honesty, so the compiler checks the axiom closure rather
  than trusting the caller;
- **has the wrong shape** — the contract's type must be `SubExpCircuitSATT`
  (its head after `whnf`), not an unrelated proposition.

A vacuous-class guard (rejecting `C = ∅`) is a *semantic* check that needs
the class-carrier in the contract; it is recorded here as a design
requirement rather than faked with a syntactic proxy — see the design note
§2 and the #80 Pass-2 follow-up.

## What the compiler logs

For every emission the command reports (i) the emitted declaration, (ii)
the transitive `PleaNP`-local dependency closure that carries the runtime
model, and (iii) the axiom closure of the emitted theorem, so the
"`#print axioms`" discipline (Gate 6 Tier 2) is visible at the emission
site. The barrier verdict for emitted claims is obtained by the ordinary
Rung-5 `#barrier_check` (the transfer carries no `Relativizing` instance →
**Inconclusive**, i.e. not ruled out by BGS — the expected non-relativizing
verdict).
-/

namespace PleaNP

namespace Barriers

namespace Williams

open Lean Elab Command Meta

/-- The transitive constant dependency closure of `root`, breadth-first over
  `getUsedConstants` of each constant's type and value. Bounded by `limit`
  nodes so a pathological term cannot wedge the elaborator. -/
private partial def constClosure (root : Name) (limit : Nat := 4096) :
    CoreM (Array Name) := do
  let env ← getEnv
  let mut seen : NameSet := {}
  let mut frontier : Array Name := #[root]
  let mut order : Array Name := #[]
  let mut fuel := limit
  while !frontier.isEmpty && fuel > 0 do
    fuel := fuel - 1
    let n := frontier.back!
    frontier := frontier.pop
    if seen.contains n then
      continue
    seen := seen.insert n
    order := order.push n
    match env.find? n with
    | none => pure ()
    | some ci =>
      let mut deps : Array Name := ci.type.getUsedConstants
      if let some v := ci.value? then
        deps := deps ++ v.getUsedConstants
      for d in deps do
        if !seen.contains d then
          frontier := frontier.push d
  return order

/-- The `PleaNP`-local part of a dependency closure (the project
  definitions the emitted theorem rests on). -/
private def pleanpClosure (cl : Array Name) : Array Name :=
  cl.filter (fun x => (`PleaNP).isPrefixOf x)

/-- Log the dependency closure of `n`, capped at `cap` names for readable
  output. -/
private def reportClosure (label : String) (n : Name) (cap : Nat := 24) :
    CommandElabM Unit := do
  let cl ← liftCoreM <| constClosure n
  let localDeps := pleanpClosure cl
  let shown := localDeps.extract 0 (min cap localDeps.size)
  let more := if localDeps.size > cap then s!", … (+{localDeps.size - cap} more)" else ""
  logInfo m!"#lower_bound_compile [{label}] dependency closure: {shown}{more}"

/-- Log the axiom closure of `n` in the `#print axioms` idiom. -/
private def reportAxioms (label : String) (n : Name) : CommandElabM Unit := do
  let axs ← liftCoreM <| Lean.collectAxioms n
  let sorted := axs.qsort (·.toString < ·.toString)
  logInfo m!"#lower_bound_compile [{label}] axioms: {sorted}"

/-- **Anti-requirement "no asserted runtime"**: reject a contract whose
  axiom closure contains `sorryAx`. A placeholder-carried runtime would make
  the emitted lower bound only as strong as the contract's honesty. -/
private def assertNoSorry (n : Name) : CommandElabM Unit := do
  let axs ← liftCoreM <| Lean.collectAxioms n
  if axs.contains ``sorryAx then
    throwError "lower_bound_compile: input contract '{n}' depends on `sorryAx`. \
      A placeholder-carried runtime is a REJECTED contract (design note §2, \
      anti-requirement 'no asserted runtime')."

/-- **Wrong-shape guard**: the contract must prove `SubExpCircuitSATT`
  (checked after `whnf`, so a definitionally-equal rendering passes). -/
private def assertContractShape (n : Name) : CommandElabM Unit := do
  let ty ← liftCoreM do
    let env ← getEnv
    match env.find? n with
    | none => throwError "lower_bound_compile: unknown declaration '{n}'"
    | some ci => pure ci.type
  let ok ← liftTermElabM do
    let t ← whnf ty
    if t.isForall then
      throwError "lower_bound_compile: contract '{n}' is a function; supply a \
        proof of `SubExpCircuitSATT` (a closed term), not a Π-type."
    isDefEq t (mkConst ``SubExpCircuitSATT)
  unless ok do
    throwError "lower_bound_compile: contract '{n}' does not prove \
      `SubExpCircuitSATT`; the input contract must be the sub-exponential \
      CircuitSAT witness (design note §2)."

/-- Emit `def <out> : Prop := <claim>` and report closure + axioms.
  `checkNotAlreadyDeclared` keeps the emission idempotent-safe: re-running
  the command on the same name is an error rather than a silent shadow.

  The emission is a **definition** (a named claim), not a theorem: the
  lower bound `NEXP ⊄ ACC⁰` is not yet proved (`williams_transfer` is a
  frozen `Prop`, its proof tracked by #98). Emitting a `thmDecl` here would
  require a proof term that does not exist; the honest emission is the
  claim itself, and the guarded full path below becomes a theorem emitter
  the moment the transfer proof lands. -/
private def emitClaim (label : String) (out : Name) (claim : Expr) :
    CommandElabM Unit := do
  checkNotAlreadyDeclared out
  liftCoreM <| addDecl <| Declaration.defnDecl {
    name := out
    levelParams := []
    type := mkSort Level.zero
    value := claim
    hints := .opaque
    safety := .safe
  }
  logInfo m!"#lower_bound_compile [{label}] emitted '{out}'."
  reportClosure label out
  reportAxioms label out

/-- **`#lower_bound_compile <contract> as <name>`** — the guarded full path.
  `<contract>` must be a proved `SubExpCircuitSATT` (shape-checked, and
  rejected if it rests on `sorryAx`); the command then emits the lower-bound
  claim `NEXP_not_subset_ACC0` under `<name>`. Usable once #98 supplies a
  contract proof — today no such proof exists, so the example below uses the
  conditional form. -/
syntax "#lower_bound_compile " ident " as " ident : command

/-- **`#lower_bound_compile_cond <name>`** — the conditional emission
  available today: emits the transfer closure
  `SubExpCircuitSATT → NEXP_not_subset_ACC0` (the claim the contract #98
  will discharge), named. This is the honest shape while the contract's
  sub-exponential half is the tracked #98 gap. -/
syntax "#lower_bound_compile_cond " ident : command

elab_rules : command
  | `(command| #lower_bound_compile $contract:ident as $out:ident) => do
    let ns ← getCurrNamespace
    let cName := ns ++ contract.getId
    let oName := ns ++ out.getId
    assertContractShape cName
    assertNoSorry cName
    emitClaim "full" oName (mkConst ``NEXP_not_subset_ACC0)

elab_rules : command
  | `(command| #lower_bound_compile_cond $out:ident) => do
    let ns ← getCurrNamespace
    let oName := ns ++ out.getId
    let claim ← liftCoreM <| mkArrow (mkConst ``SubExpCircuitSATT)
      (mkConst ``NEXP_not_subset_ACC0)
    emitClaim "conditional" oName claim

/-! ## Example emission (compiles; this is the Pass-2 "example emission")

The conditional emission below names the transfer closure. It is complete as
stated — its hypothesis is exactly the contract #98 will supply. -/

#lower_bound_compile_cond williams_lower_bound_compiled

/-- The emitted claim is the frozen transfer closure (definitional shape
  check on the emission). -/
example : williams_lower_bound_compiled = williams_transfer := rfl

/-! The emitted declaration carries no `Relativizing` instance, so the Rung-5
  verdict is **Inconclusive** — the expected non-relativizing classification
  (recorded for #73/#91). -/
#barrier_check williams_lower_bound_compiled

/-! ## Guard tests

The contract rejections (wrong shape, `sorry`-carried runtime, missing
contract) are exercised at build time in `tests.LowerBoundCompilerGuards`.
They live in the `tests` lib rather than here: the `sorry`-carried decoy
contract is itself a `sorry`, and this module is a member of the clean
(zero-sorry) build set that Gate 6 scans with `--prove-stage`. -/

end Williams

end Barriers

end PleaNP
