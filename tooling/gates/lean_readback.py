#!/usr/bin/env python3
"""Extract a Lean declaration's type and render it as a structured plain-English
skeleton (the rule-based half of the read-back harness).

This is the *deterministic* translator for Gate 4 (read-back) /
docs/STATEMENTS/SEMANTIC_APPROVAL.md. It renders the *shape* of a Lean
proposition into English: the quantifier order, the connectives, and the
head constants. It does NOT claim to fully understand the math — it produces
the English that two independent passes must converge on.

Design:
- `extract_type(module, theorem, lean_dir)` runs `#check` / `#print` via
  `lake env lean` and returns the pretty-printed type as text.
- `render(lean_type_text)` is a rule-based structural renderer: binder names,
  `->` / `<-` / `not` / `and` / `or` / `=` / `Exists` show up as English phrases,
  and unknown constants are passed through in backticks so an LLM or a human
  can see exactly which head terms were not interpreted.

Usage (from the lean/ directory):
    python3 ../tooling/gates/lean_readback.py PleaNP.Oracles.evalsTo_unique_result

No LLM, no secrets: deterministic output, runnable in CI.
"""
from __future__ import annotations

import re
import subprocess
import sys
import tempfile
from pathlib import Path


def extract_type(module: str, decl: str, lean_dir: Path) -> str:
    """Return the pretty-printed type of `decl` (a fully-qualified name) by
    asking Lean to type-check a trivial use and print it.

    We use `#check` on a proxy that forces Lean to print the type.  For a
    theorem `decl : T`, `#check (decl)` prints `decl : T`.  We then strip the
    leading `decl : ` to obtain `T`.
    """
    # A .lean that imports the module(s) and #checks the decl.
    mods = module.split(",")
    lines = [f"import {m}" for m in mods]
    lines.append("")
    # Fuze trick: check the decl itself; Lean prints '<decl> : <type>'.
    lines.append(f"#check {decl}")
    src = "\n".join(lines) + "\n"
    with tempfile.NamedTemporaryFile("w", suffix=".lean", delete=False) as f:
        f.write(src)
        checker = Path(f.name)
    try:
        cmd = ["lake", "env", "lean", str(checker)]
        proc = subprocess.run(cmd, cwd=str(lean_dir), capture_output=True,
                              text=True, timeout=420)
        out = (proc.stdout or "") + (proc.stderr or "")
        # Lean prints:  <decl> <params> : <type>   (possibly across MULTIPLE
        # lines — parameterized theorems print the proposition body indented
        # on the next line(s)). Join the signature line with every following
        # blank/indented continuation until a blank line.
        marker = f"{decl}"
        type_text = None
        lines = out.splitlines()
        for i, line in enumerate(lines):
            if line.strip().startswith(marker) and " : " in line:
                collected = [line.strip()]
                # continuation lines: indented (start with space) and non-empty
                for cont in lines[i + 1:]:
                    if cont.strip() == "":
                        break
                    if cont[0] in (" ", "\t"):
                        collected.append(cont.strip())
                    else:
                        break
                # Reconstruct the full type: the first line is '<decl> <params> : <body>'
                # (params may contain ':' themselves), and continuation lines are
                # the rest of the body. The decl name is the first token; strip
                # it, keep everything else (params + body) joined.
                first_tok = line.strip().split(" ", 1)[0]
                rest = line.strip()[len(first_tok):].strip()
                full = " ".join([rest] + collected[1:])
                type_text = full
                break
        if type_text is None:
            # fallback: last non-empty line of the check output
            for line in reversed(out.splitlines()):
                if " : " in line:
                    type_text = line.strip()
                    break
        if type_text is None:
            raise RuntimeError(f"could not extract type of {decl}; output was:\n{out}")
        return type_text
    finally:
        checker.unlink(missing_ok=True)


def extract_body(module: str, decl: str, lean_dir: Path) -> str:
    """Return the BODY of a `def` (its value) — for defs whose *type* is just
    `Prop` but whose proposition lives in the body (e.g. thhStatement).

    Uses `#print <decl>` and returns the text after the first ':=' / ': ' that

    introduces the value. Falls back to extract_type (theorem case) if #print
    shows no body (theorem-valued constants store no body).
    """
    mods = module.split(",")
    src = "\n".join([f"import {m}" for m in mods] + ["", f"#print {decl}"]) + "\n"
    with tempfile.NamedTemporaryFile("w", suffix=".lean", delete=False) as f:
        f.write(src)
        checker = Path(f.name)
    try:
        proc = subprocess.run(["lake", "env", "lean", str(checker)],
                              cwd=str(lean_dir), capture_output=True,
                              text=True, timeout=420)
        out = (proc.stdout or "") + (proc.stderr or "")
    finally:
        checker.unlink(missing_ok=True)
    lines = out.splitlines()
    for i, line in enumerate(lines):
        s = line.strip()
        # 'def' may be preceded by attributes (e.g. '@[reducible]'): find the
        # 'def' keyword position.
        di = s.find("def ")
        if di != -1 and ":=" in s[di:]:
            # Body after ':=' on this line, plus any following indented lines
            # (continuation of the body on subsequent lines).
            head = s[di + len("def "):]
            body = head.split(":=", 1)[1].strip() if ":=" in head else ""
            collected = [body] if body else []
            for cont in lines[i + 1:]:
                cs = cont.strip()
                if cs == "":
                    break
                # Continuation lines may start with '∀' (not whitespace); they
                # belong to this decl's body until a new top-level keyword.
                if cs.startswith(("def ", "theorem ", "lemma ", "instance ",
                                   "structure ", "class ", "abbrev ",
                                   "import ", "end ")):
                    break
                collected.append(cs)
            full = " ".join(x for x in collected if x)
            if full:
                return full
    # No body found (theorem) — fall back to the type.
    return extract_type(module, decl, lean_dir)


# --- structural English renderer -------------------------------------------

def _strip_coercions(text: str) -> str:
    """Plain-text cleanup of the pretty-printed Lean type."""
    text = text.replace("∀", "forall ")
    text = text.replace("∃", "exists ")
    text = text.replace("¬", "not ")
    text = text.replace("∧", " and ")
    text = text.replace("∨", " or ")
    text = text.replace("→", " -> ")
    text = text.replace("↔", " iff ")
    text = text.replace("≠", " != ")
    text = text.replace("∈", " in ")
    return text


def render(lean_type: str) -> str:
    """Rule-based structural renderer of a Lean type into English.

    Deliberately conservative: it rewrites the quantifier/connective skeleton
    into English and leaves all unknown constants in backticks so no semantic
    claim is silently invented. Two independent translators can then both be
    checked against *this* skeleton (the deterministic ground truth of shape).
    """
    t = _strip_coercions(lean_type)
    # Quantifiers: 'forall x : T, ...' -> 'for every x of type T, ...'
    t = re.sub(r"forall\s+([A-Za-z_][A-Za-z0-9_']*)\s*:\s*([^,]+?),",
               r"for every \1 (a \2),", t)
    t = re.sub(r"exists\s+([A-Za-z_][A-Za-z0-9_']*)\s*:\s*([^,]+?),",
               r"there exists \1 (of type \2) such that", t)
    # Bare hypothesis groups '(x₁ : T₁) ... (xₙ : Tₙ)' preceding a ':'
    # (the implicit-params display) — turn into 'given x₁ of type T₁ ...'.
    t = re.sub(r"\(\s*([A-Za-z_][A-Za-z0-9_']*)\s*:\s*([^)]+?)\)",
               r"given \1 of type \2", t)
    # The top-level conclusion ': C' after hypotheses -> rephrase
    #   '<hypothesis groups> : <conclusion>' is handled by the above; the
    #   remaining ': ' is a colon in the original. Keep it as 'then'.
    #   We do NOT rewrite a lone ':' inside a type (e.g. function arrows),
    #   only the outermost conclusion separator — handled below.
    t = re.sub(r"\bnot\b", "it is not the case that", t)
    t = re.sub(r"\s+and\s+", " and ", t)
    t = re.sub(r"\s+or\s+", " or ", t)
    t = re.sub(r"\s+iff\s+", " if and only if ", t)
    t = re.sub(r"\s+->\s+", " implies ", t)
    t = re.sub(r"\s+!=\s+", " is not equal to ", t)
    # Equalities: rewrite a top-level ' : ' conclusion 'c = c'' is tricky;
    # handle simple 'x = y' (no surrounding function arrow) to 'x equals y'.
    t = re.sub(r"\s+=\s+", " equals ", t)
    # Collapse double spaces
    t = re.sub(r"\s{2,}", " ", t).strip()
    return t


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    decl = sys.argv[1]
    module = sys.argv[2] if len(sys.argv) > 2 else None
    lean_dir = Path.cwd()
    if module is None:
        # require module arg; document in help
        print("error: usage: lean_readback.py '<decl>' '<module[,module...]>'", file=sys.stderr)
        return 2
    try:
        t = extract_type(module, decl, lean_dir)
    except RuntimeError as e:
        print(e, file=sys.stderr)
        return 1
    print("TYPE:", t)
    print("ENGLISH:", render(t))
    return 0


if __name__ == "__main__":
    sys.exit(main())