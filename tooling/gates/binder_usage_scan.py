#!/usr/bin/env python3
"""Gate 5 (Tier 1b) -- binder-usage / "lethality" scanner for PleaNP Lean source.

DRAFT (independent authoring track A). Another agent may draft the same gate
independently; reconcile the two before CI wiring (Gate-3-style dual
authoring applied to the gates themselves).

Every parameter, bound variable, and declaration must be LOAD-BEARING. This
scanner catches the "compiles clean but semantically inert" failure shapes
that hygiene_scan.py (Gate 6: dishonest shortcuts) and vacuity_scan.py
(Gate 5 Tier 1: syntactically vacuous bodies) both miss -- the shapes found
in the first PleaNP definitional renderings (2026-08-19 review):

- Flaw A shape: a predicate whose parameters never occur in the body
  (a `DecidesInTime` that never uses its time bound, input encoding, or
  machine -- the definition is constant in the things it claims to
  constrain).
- Flaw B shape: a helper that computes a value and DISCARDS it
  (`let _answer := oracle q`), or a declaration that nothing references
  (the oracle query path never wired into the step function).
- Flaw C shape: a quantifier binder that doesn't constrain its own body
  (`exists y, bound y and Accepts M (x, 0)` -- the certificate is vacuous).

Checks:
  1. Unused definition parameters. For def/abbrev: every named explicit
     binder must occur later in the signature or body (VIOLATION); implicit
     and instance binders are REVIEW. For theorem/lemma: binders are searched
     in the whole block including the proof, and flagged as REVIEW (an unused
     hypothesis is usually benign, but in a frozen statement it can mean the
     hypothesis isn't doing the work the spec claims).
  2. Quantifier lethality. For each `exists`-binder: if the bound name never
     occurs in the quantifier body, VIOLATION (vacuous witness); if the body
     is a top-level conjunction with conjuncts that never mention the name,
     REVIEW (weakly constrained witness -- the Flaw C shape). For each
     `forall`-binder whose name never occurs in the body, REVIEW (the claim
     is constant in the quantified variable). Scanned in def bodies and in
     theorem STATEMENTS (the part before `:=`), not in tactic proofs.
  3. Discarded let-bindings: `let _x := v` (REVIEW -- the computed value is
     thrown away; the Flaw B shape).
  4. Unreferenced declarations: a def/theorem/lemma/abbrev/structure whose
     name occurs in no other declaration across the scanned tree (REVIEW --
     dead code, or integration that was specified but never wired). Skip
     instances (found by typeclass resolution, name legitimately unused).
     Frozen statement theorems (entry points referenced only by specs) will
     be flagged -- that is why this tier is REVIEW, and why
     --allow-unreferenced exists.

This is a Tier 1 heuristic scanner (text, no Lean toolchain). It does NOT
catch: parameters used only cosmetically (e.g. `_ = M` conjuncts), influence
that is wired but semantically wrong, or structure fields never read. Those
remain Gate 4 (read-back) and the validation suite's job
(docs/STATEMENTS/ValidationSuite.spec.md). "Lethality scan passed" = Tier 1b
+ review, never Tier 1b alone.

Usage:
    python3 binder_usage_scan.py <path> [<path>...]
    python3 binder_usage_scan.py --strict lean/PleaNP   # REVIEWs also fail
    python3 binder_usage_scan.py --allow-unreferenced '^exists_' lean/PleaNP

Exit codes:
    0  no violations (REVIEWs may be present unless --strict)
    1  violations found
    2  usage error
"""
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass
class Finding:
    file: Path
    line_no: int
    kind: str          # see _report for the vocabulary
    name: str
    detail: str
    severity: str      # "VIOLATION" | "REVIEW"


_IDENT = r"[A-Za-z_][A-Za-z0-9_'.]*"
_IDENT_RE = re.compile(r"^" + _IDENT + r"$")

DECL_START_RE = re.compile(
    r"^(def|theorem|lemma|structure|class|inductive|instance|abbrev|axiom|constant)\s+(\S+)",
    re.MULTILINE,
)

_OPEN_TO_CLOSE = {"(": ")", "{": "}", "[": "]"}


def _strip_comments(src: str) -> str:
    """Remove block comments /- ... -/ and line comments -- (non-nested strip).

    NOTE: the closing pattern is `-/` WITHOUT a required leading space. The
    other Tier 1 scanners (hygiene/vacuity) use `/-.*? -/`, which fails to
    strip docstrings that close with `\\n-/` (the Mathlib convention) and can
    over-strip from the first `/-` to a later ` -/` -- deleting real code.
    That shared bug is reported separately; this scanner does not inherit it.

    Comments are BLANKED (replaced by equal-length whitespace), not deleted,
    so all reported line numbers are true file coordinates."""
    def _blank(m: re.Match) -> str:
        return "".join("\n" if c == "\n" else " " for c in m.group(0))

    src = re.sub(r"/-.*?-/", _blank, src, flags=re.DOTALL)
    src = re.sub(r"--.*?$", _blank, src, flags=re.MULTILINE)
    return src


def _split_decls(src: str) -> list[tuple[str, str, int, str]]:
    """Split source into (kind, name, start_offset, block) per top-level decl."""
    decls = [(m.group(1), m.group(2), m.start()) for m in DECL_START_RE.finditer(src)]
    blocks = []
    for i, (kind, name, start) in enumerate(decls):
        end = decls[i + 1][2] if i + 1 < len(decls) else len(src)
        blocks.append((kind, name, start, src[start:end]))
    return blocks


def _line_of(src: str, offset: int) -> int:
    return src.count("\n", 0, offset) + 1


def _matching_paren(text: str, open_idx: int) -> int | None:
    """Index of the close matching text[open_idx], or None if unbalanced."""
    depth = 0
    for i in range(open_idx, len(text)):
        c = text[i]
        if c in _OPEN_TO_CLOSE:
            depth += 1
        elif c in ")]}":
            depth -= 1
            if depth == 0:
                return i
    return None


def _depth0_split(text: str, sep: str) -> list[str]:
    """Split text on sep occurrences at bracket depth 0 (tracks (){}[] and
    angle-bracket anonymous constructors)."""
    parts, depth, last = [], 0, 0
    for i, c in enumerate(text):
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif c == "⟨":
            depth += 1
        elif c == "⟩":
            depth -= 1
        elif c == sep and depth == 0:
            parts.append(text[last:i])
            last = i + 1
    parts.append(text[last:])
    return parts


def _depth0_pos(text: str, needle: str) -> int | None:
    """First index of needle at bracket depth 0."""
    depth = 0
    for i, c in enumerate(text):
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif c == needle and depth == 0:
            return i
    return None


def _extract_binder_names(group_inner: str) -> list[str]:
    """Names from a binder group's inner text: the identifiers before the
    first depth-0 ':' (e.g. 'x y' from '(x y : alpha)'). Groups without a
    depth-0 colon are unnamed instance implicits or typed ascriptions --
    skipped (None-equivalent: empty list), except a lone bare identifier."""
    colon = _depth0_pos(group_inner, ":")
    if colon is None:
        inner = group_inner.strip()
        return [inner] if _IDENT_RE.match(inner) and not inner.startswith("_") else []
    head = group_inner[:colon]
    return [t for t in re.findall(_IDENT, head) if not t.startswith("_")]


def _word_occurs(name: str, text: str) -> bool:
    return re.search(r"(?<![A-Za-z0-9_'.])" + re.escape(name) + r"(?![A-Za-z0-9_'])", text) is not None


def _depth0_find(text: str, needle: str) -> int | None:
    """First index of a multi-char token at bracket depth 0."""
    depth = 0
    for i, c in enumerate(text):
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif depth == 0 and text.startswith(needle, i):
            return i
    return None


def _check_decl_binders(path: Path, src: str, kind: str, name: str,
                        start: int, block: str) -> list[Finding]:
    """Check 1: every named binder in the signature must be load-bearing."""
    findings: list[Finding] = []
    if kind not in ("def", "abbrev", "theorem", "lemma"):
        return findings
    # Split signature/body at the TOP-LEVEL ':=' -- a bare find(':=") would
    # cut inside named arguments like `(α := QueryType)` in the statement.
    body_idx = _depth0_find(block, ":=")
    sig = block if body_idx is None else block[:body_idx]
    # Skip the decl keyword and name; scan depth-0 groups in the signature.
    name_end = sig.find(name) + len(name)
    i = name_end
    while i < len(sig):
        c = sig[i]
        if c in "([" or (c == "{" and not sig.startswith(".{", i)):
            close = _matching_paren(sig, i)
            if close is None:
                break
            inner = sig[i + 1:close]
            # A group containing ':=' at depth 0 is a named argument like
            # (a := b) in the result type, not a binder.
            if re.search(r":=", inner) is None:
                for nm in _extract_binder_names(inner):
                    after = sig[close + 1:] + ("" if body_idx is None else block[body_idx:])
                    # Theorems: hypotheses are discharged in the proof, so the
                    # whole block is the usage window; defs: signature tail + body.
                    window = block if kind in ("theorem", "lemma") else after
                    if not _word_occurs(nm, window):
                        if kind in ("theorem", "lemma"):
                            sev, knd = "REVIEW", "unused_hypothesis"
                        elif c == "(":
                            sev, knd = "VIOLATION", "unused_param"
                        else:
                            sev, knd = "REVIEW", "unused_implicit"
                        findings.append(Finding(
                            path, _line_of(src, start + i), knd, nm,
                            f"binder '{nm}' never occurs after its own group in {kind} '{name}'",
                            sev))
            i = close + 1
        else:
            i += 1
    return findings


def _parse_quant_binders(window: str, qpos: int) -> tuple[list[str], int] | None:
    """Parse binders after an exists/forall at qpos. Returns (names, body_start)
    where body_start is the index just past the top-level comma."""
    i = qpos + 1
    names: list[str] = []
    while True:
        while i < len(window) and window[i].isspace():
            i += 1
        if i >= len(window):
            return None
        if window[i] in "({":
            close = _matching_paren(window, i)
            if close is None:
                return None
            names.extend(_extract_binder_names(window[i + 1:close]))
            i = close + 1
            continue
        # Bare binder run up to a depth-0 comma: 'x y : T, ...' or 'x, ...'
        comma = _depth0_pos(window[i:], ",")
        if comma is None:
            return None
        head = window[i:i + comma]
        colon = _depth0_pos(head, ":")
        name_part = head if colon is None else head[:colon]
        names.extend(t for t in re.findall(_IDENT, name_part) if not t.startswith("_"))
        return (names, i + comma + 1) if names else None


def _check_quantifiers(path: Path, src: str, kind: str, name: str,
                       start: int, block: str) -> list[Finding]:
    """Check 2: quantifier binders must constrain their bodies."""
    findings: list[Finding] = []
    if kind not in ("def", "abbrev", "theorem", "lemma"):
        return findings
    # Theorems: the statement is what must be lethal; tactic proofs are exempt.
    # Split at the top-level ':=' so named arguments `(α := T)` inside the
    # statement don't truncate the window early.
    if kind in ("theorem", "lemma"):
        cut = _depth0_find(block, ":=")
        window = block if cut is None else block[:cut]
    else:
        window = block
    for m in re.finditer(r"[∃∀]", window):
        q, qpos = m.group(0), m.start()
        parsed = _parse_quant_binders(window, qpos)
        if parsed is None:
            continue
        names, body_start = parsed
        body = window[body_start:]
        conjuncts = _depth0_split(body, "∧")
        for nm in names:
            if not _word_occurs(nm, body):
                sev = "VIOLATION" if q == "∃" else "REVIEW"
                findings.append(Finding(
                    path, _line_of(src, start + qpos),
                    "vacuous_witness" if q == "∃" else "vacuous_forall", nm,
                    f"'{q} {nm}' in '{name}': bound variable never occurs in the body",
                    sev))
            elif q == "∃" and len(names) == 1 and len(conjuncts) > 1:
                # Weakly-constrained-witness check: single-binder ∃ only.
                # Multi-binder ∃s are witness packaging (∃ tm h ea oa M p, ...)
                # where distributing binders across conjuncts is legitimate.
                free_conjuncts = [c.strip() for c in conjuncts
                                  if not _word_occurs(nm, c) and re.search(r"[A-Za-z]", c)]
                for c in free_conjuncts:
                    snippet = c.split("\n", 1)[0].strip()[:80]
                    findings.append(Finding(
                        path, _line_of(src, start + qpos),
                        "weakly_constrained_witness", nm,
                        f"'∃ {nm}' in '{name}': conjunct does not mention the witness "
                        f"-- verify it is intentional: {snippet}",
                        "REVIEW"))
    return findings


def _check_discarded_lets(path: Path, src: str, blocks) -> list[Finding]:
    """Check 3: `let _x := v` computes v and throws it away."""
    findings: list[Finding] = []
    for kind, name, start, block in blocks:
        if kind in ("structure", "class", "inductive"):
            continue
        for m in re.finditer(r"\blet\s+(_[A-Za-z0-9_']*)\s*:?=", block):
            findings.append(Finding(
                path, _line_of(src, start + m.start()), "discarded_let", m.group(1),
                f"discarded let-binding in '{name}': the value is computed and never used",
                "REVIEW"))
    return findings


def _check_unreferenced(path_blocks: dict[Path, tuple[str, list]],
                        allow_re: re.Pattern | None) -> list[Finding]:
    """Check 4: declarations referenced by nothing else in the scanned tree."""
    findings: list[Finding] = []
    # Gather all blocks with file provenance.
    all_decls: list[tuple[Path, str, str, int, str]] = []
    for path, (src, blocks) in path_blocks.items():
        for kind, name, start, block in blocks:
            all_decls.append((path, kind, name, start, block))
    for path, kind, name, start, block in all_decls:
        if kind in ("instance", "axiom", "constant", "inductive"):
            continue
        if allow_re and allow_re.search(name):
            continue
        short = name.split(".")[-1]
        referenced = False
        for opath, _k, _n, _s, oblock in all_decls:
            if opath == path and _s == start:
                continue  # the declaration's own block
            if _word_occurs(name, oblock) or _word_occurs(short, oblock):
                referenced = True
                break
        if not referenced:
            src = path_blocks[path][0]
            findings.append(Finding(
                path, _line_of(src, start), "unreferenced_decl", name,
                f"{kind} '{name}' is referenced by no other scanned declaration "
                f"-- dead code, or integration specified but never wired",
                "REVIEW"))
    return findings


def scan(paths: list[Path], allow_re: re.Pattern | None) -> list[Finding]:
    files: list[Path] = []
    for p in paths:
        if p.is_dir():
            files.extend(sorted(p.rglob("*.lean")))
        elif p.suffix == ".lean":
            files.append(p)
    files = sorted(set(files))

    findings: list[Finding] = []
    path_blocks: dict[Path, tuple[str, list]] = {}
    for f in files:
        try:
            raw = f.read_text(encoding="utf-8", errors="replace")
        except Exception as e:
            print(f"warning: could not read {f}: {e}", file=sys.stderr)
            continue
        src = _strip_comments(raw)
        blocks = _split_decls(src)
        path_blocks[f] = (src, blocks)
        for kind, name, start, block in blocks:
            findings.extend(_check_decl_binders(f, src, kind, name, start, block))
            findings.extend(_check_quantifiers(f, src, kind, name, start, block))
        findings.extend(_check_discarded_lets(f, src, blocks))
    findings.extend(_check_unreferenced(path_blocks, allow_re))
    return findings


def main() -> int:
    ap = argparse.ArgumentParser(description="Gate 5 (Tier 1b) binder-usage / lethality scanner")
    ap.add_argument("path", nargs="+", type=Path, help=".lean file or dir to scan")
    ap.add_argument("--strict", action="store_true",
                    help="Treat REVIEW findings as failures too")
    ap.add_argument("--allow-unreferenced", metavar="REGEX", default=None,
                    help="Declaration names matching REGEX are exempt from the "
                         "unreferenced-declaration check (e.g. frozen entry points)")
    args = ap.parse_args()

    allow_re = re.compile(args.allow_unreferenced) if args.allow_unreferenced else None
    findings = scan(args.path, allow_re)

    violations = [f for f in findings if f.severity == "VIOLATION"]
    reviews = [f for f in findings if f.severity == "REVIEW"]

    if findings:
        print(f"Gate 5 (Tier 1b) findings across {len(set(f.file for f in findings))} file(s):")
        for f in sorted(findings, key=lambda f: (str(f.file), f.line_no)):
            print(f"  [{f.severity}] {f.kind:26} {f.file}:{f.line_no}  {f.name!r}  | {f.detail}")
        print()
        print(f"  {len(violations)} violation(s), {len(reviews)} review item(s)")
        if violations or (args.strict and reviews):
            return 1
    else:
        print(f"Gate 5 (Tier 1b) clean: every binder and declaration is load-bearing "
              f"in {len(args.path)} path(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
