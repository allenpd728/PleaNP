#!/usr/bin/env python3
"""Guard: the root `lakefile.lean` and `lean/lakefile.lean` must not drift.

Why this exists (PleaNP #102). Downstream Lake projects resolve a dependency's
package root at the *repo root*, so PleaNP needs a root `lakefile.lean` for repos
like Maith to `require PleaNP`. But PleaNP's own build commands all run from
`lean/`, and Lake picks the nearest lakefile — so `lean/lakefile.lean` stays
authoritative for those.

The root file therefore has to restate the library declarations, and the two can
drift. A minimal root file (package + `srcDir` only, no `lean_lib`) was tested and
does NOT work: consumers fail with `unknown module prefix 'PleaNP'` because no
library is declared, so nothing is built and no oleans exist. The duplication is
unavoidable; this check makes it safe.

What it compares:
  - the `package` name
  - every `lean_lib` name and its `globs`/`roots` setting
  - every `lean_exe` name and its `root`
  - the `require mathlib` pin (repo URL + version tag)

What it deliberately does NOT compare:
  - `srcDir` (legitimately differs: root is `lean`, inner is the default/unset)
  - comments, ordering, whitespace

Usage:
    python3 tooling/gates/lakefile_sync_check.py

Exit codes: 0 in sync, 1 drift detected, 2 usage/read error.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
ROOT_LAKEFILE = REPO / "lakefile.lean"
LEAN_LAKEFILE = REPO / "lean" / "lakefile.lean"

PACKAGE_RE = re.compile(r"^\s*package\s+[«\"]?([A-Za-z0-9_«»]+)", re.MULTILINE)
GLOBS_RE = re.compile(r"(globs|roots)\s*:=\s*#\[([^\]]*)\]", re.DOTALL)
EXE_ROOT_RE = re.compile(r"root\s*:=\s*`([A-Za-z0-9_.]+)")
REQUIRE_RE = re.compile(
    r'require\s+(\w+)\s+from\s+git\s+"([^"]+)"\s*@\s*"([^"]+)"'
)
NEXT_DECL_RE = re.compile(r"\n\s*(lean_lib|lean_exe|package|require)\b")


def _strip_comments(src: str) -> str:
    """Remove /- ... -/ and -- comments so commented-out declarations don't count."""
    src = re.sub(r"/-.*?-/", "", src, flags=re.DOTALL)
    src = re.sub(r"--.*?$", "", src, flags=re.MULTILINE)
    return src


def _norm(body: str) -> str:
    """Canonicalise a setting RHS so formatting-only differences don't fail.

    Collapses runs of whitespace, then removes spaces just inside brackets and
    before commas — `#[ `a ,  `b ]` and `#[`a, `b]` must compare equal, or a
    harmless reformat would be reported as drift and train people to ignore the
    guard.
    """
    s = re.sub(r"\s+", " ", body).strip()
    s = re.sub(r"\[\s+", "[", s)
    s = re.sub(r"\s+\]", "]", s)
    s = re.sub(r"\s+,", ",", s)
    return s


def _decls(src: str, keyword: str) -> dict:
    """Collect {name: setting} for each `keyword Name where ...` declaration."""
    out: dict[str, str] = {}
    for chunk in re.split(rf"^\s*{keyword}\s+", src, flags=re.MULTILINE)[1:]:
        m = re.match(r"[«\"]?([A-Za-z0-9_«»]+)", chunk)
        if not m:
            continue
        name = m.group(1).strip("«»")
        stop = NEXT_DECL_RE.search(chunk)
        setting = chunk[: stop.start()] if stop else chunk
        out[name] = setting
    return out


def _lib_setting(setting: str) -> str:
    g = GLOBS_RE.search(setting)
    return _norm(g.group(2)) if g else ""


def _exe_setting(setting: str) -> str:
    r = EXE_ROOT_RE.search(setting)
    return r.group(1) if r else ""


def describe(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"missing lakefile: {path}")
    src = _strip_comments(path.read_text(encoding="utf-8"))

    pkg_m = PACKAGE_RE.search(src)
    pkg = pkg_m.group(1).strip("«»") if pkg_m else None

    libs = {n: _lib_setting(s) for n, s in _decls(src, "lean_lib").items()}
    exes = {n: _exe_setting(s) for n, s in _decls(src, "lean_exe").items()}
    requires = {
        m.group(1): (m.group(2), m.group(3)) for m in REQUIRE_RE.finditer(src)
    }
    return {"package": pkg, "libs": libs, "exes": exes, "requires": requires}


def _diff(label: str, a: dict, b: dict, fmt) -> list[str]:
    problems = []
    only_a = sorted(set(a) - set(b))
    only_b = sorted(set(b) - set(a))
    if only_a:
        problems.append(f"{label} declared only in root lakefile: {only_a}")
    if only_b:
        problems.append(f"{label} declared only in lean/lakefile.lean: {only_b}")
    for name in sorted(set(a) & set(b)):
        if a[name] != b[name]:
            problems.append(
                f"{label} {name!r} setting differs:\n"
                f"      root   : {fmt(a[name])!r}\n"
                f"      lean/  : {fmt(b[name])!r}"
            )
    return problems


def main() -> int:
    try:
        root = describe(ROOT_LAKEFILE)
        inner = describe(LEAN_LAKEFILE)
    except (FileNotFoundError, OSError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2

    problems: list[str] = []
    if root["package"] != inner["package"]:
        problems.append(
            f"package name differs: root={root['package']!r} lean/={inner['package']!r}"
        )
    problems += _diff("lean_lib", root["libs"], inner["libs"], lambda s: s)
    problems += _diff("lean_exe", root["exes"], inner["exes"], lambda s: s)
    if root["requires"] != inner["requires"]:
        problems.append(
            f"`require` pins differ:\n"
            f"      root   : {root['requires']}\n"
            f"      lean/  : {inner['requires']}"
        )

    if problems:
        print("LAKEFILE SYNC DRIFT — the root shim and lean/lakefile.lean disagree:")
        for p in problems:
            print(f"  - {p}")
        print()
        print("The root file exists so downstream repos can `require PleaNP` (#102);")
        print("`lean/lakefile.lean` stays authoritative for PleaNP's own build commands.")
        print("Update BOTH so they declare the same libraries, then re-run this check.")
        return 1

    print("lakefile sync OK — root shim and lean/lakefile.lean agree on")
    print(
        f"  package={root['package']!r} libs={sorted(root['libs'])} "
        f"exes={sorted(root['exes'])} requires={sorted(root['requires'])}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())