#!/usr/bin/env python3
"""Gate 3 multi-rendering driver — "AI produces many renderings; humans mine the shape."

The model: let AI (agents / LLM passes) produce MANY independent Lean
renderings of the same informal statement; the machine checks pairwise
equivalence; the DISAGREEMENTS (where renderings are NOT provably equivalent)
are the interesting places — they reveal where the statement's shape is
ambiguous and can be silently wrong. Those disagreements are pooled into the
review inbox as human-mine points (one plain-language question each), and
the human mines them via GitHub issues (comment `confirm` / `flag <reason>`).

Pipeline (per target statement):
  1. `init`   — create a multi-rendering workspace: the informal claim + N slots.
  2. `render` — an agent writes its independent rendering (a Lean theorem in a
                module), registered under a slot id.
  3. `check`  — run pairwise `dual_render.check_equivalence` over all
                registered renderings; build an equivalence matrix.
  4. `mine`   — for each pair that is NOT machine-verified equivalent, emit a
                review point into the review inbox (which the review-issue
                workflow turns into a GitHub issue for the human).

The multi-rendering workspace lives in `churn/<claim-slug>/` (dir kept as churn for git stability):
    informal.md        the informal claim (the seed)
    renderings/<id>.lean   each independent rendering
    matrix.json        pairwise equivalence results (machine-verified)
    mined/             review points emitted (one per disagreement)

Usage (from the repo root):
    python3 tooling/gates/multi_render.py init <slug> "<informal claim>"
    python3 tooling/gates/multi_render.py render <slug> <id> <module> <theorem>
    python3 tooling/gates/multi_render.py check <slug> [--lean-dir lean]
    python3 tooling/gates/multi_render.py mine <slug>

Exit codes: 0 ok, 1 error, 2 usage.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import itertools
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHURN = ROOT / "churn"

sys.path.insert(0, str(Path(__file__).parent))
sys.path.insert(0, str(Path(__file__).parent.parent / "reviews"))
import dual_render  # noqa: E402
import review_inbox  # noqa: E402


def _ws(slug: str) -> Path:
    return CHURN / slug


def init(slug: str, informal: str) -> int:
    ws = _ws(slug)
    (ws / "renderings").mkdir(parents=True, exist_ok=True)
    (ws / "mined").mkdir(parents=True, exist_ok=True)
    (ws / "informal.md").write_text(
        f"# {slug}\n\nInformal claim:\n\n> {informal}\n", encoding="utf-8")
    try:
        shown = ws.relative_to(ROOT)
    except ValueError:
        shown = ws
    print(f"multi-rendering workspace: {shown}")
    return 0


def render(slug: str, rid: str, module: str, theorem: str) -> int:
    ws = _ws(slug)
    if not ws.exists():
        print(f"error: no multi-rendering workspace for {slug!r} (run init first)", file=sys.stderr)
        return 1
    entry = {"id": rid, "module": module, "theorem": theorem,
             "created": _dt.datetime.now(_dt.timezone.utc).isoformat()}
    reg = ws / "renderings" / f"{rid}.json"
    reg.write_text(json.dumps(entry, indent=2), encoding="utf-8")
    print(f"registered rendering {rid}: {module} / {theorem}")
    return 0


def _load_renderings(slug: str) -> list[dict]:
    ws = _ws(slug)
    out = []
    for f in sorted((ws / "renderings").glob("*.json")):
        out.append(json.loads(f.read_text(encoding="utf-8")))
    return out


def check(slug: str, lean_dir: Path, lemmas: dict | None = None) -> int:
    ws = _ws(slug)
    rs = _load_renderings(slug)
    if len(rs) < 2:
        print("need at least 2 renderings to check equivalence", file=sys.stderr)
        return 1
    matrix = {"slug": slug, "pairs": []}
    for a, b in itertools.combinations(rs, 2):
        lemma = None
        if lemmas:
            lemma = lemmas.get(f"{a['id']}|{b['id']}") or lemmas.get(f"{b['id']}|{a['id']}")
        ok, detail = dual_render.check_equivalence(
            lean_dir, a["module"], a["theorem"], b["module"], b["theorem"],
            lemma=lemma)
        matrix["pairs"].append({
            "a": a["id"], "b": b["id"],
            "equivalent": ok, "detail": detail[:200],
        })
        print(f"{a['id']} ~ {b['id']}: {'EQUIVALENT' if ok else 'DISAGREE'}")
    (ws / "matrix.json").write_text(json.dumps(matrix, indent=2), encoding="utf-8")
    try:
        shown = (ws / "matrix.json").relative_to(ROOT)
    except ValueError:
        shown = ws / "matrix.json"
    print(f"wrote {shown}")
    return 0


def mine(slug: str) -> int:
    ws = _ws(slug)
    matrix = json.loads((ws / "matrix.json").read_text(encoding="utf-8"))
    informal = (ws / "informal.md").read_text(encoding="utf-8").split("> ", 1)[-1].strip()
    mined = 0
    for pair in matrix["pairs"]:
        if pair["equivalent"]:
            continue
        # A disagreement -> one human-mine review point.
        q = (f"Two independent renderings of the claim '{slug}' are NOT "
             f"machine-verified equivalent (rendering {pair['a']} vs "
             f"{pair['b']}). They disagree on the shape. Which matches your "
             f"intention — or is the informal claim ambiguous?")
        rc = review_inbox.add([
            "kind=semantic-review",
            f"run=multi-rendering-{slug}",
            "agent=multi-rendering",
            f"created={_dt.datetime.now(_dt.timezone.utc).isoformat()}",
            f"claim={slug} (Gate 3 disagreement)",
            f"module={pair['a']},{pair['b']}",
            f"decl={pair['a']},{pair['b']}",
            f"machine_summary=Gate 3 multi-rendering: renderings {pair['a']} and {pair['b']} disagree",
            f"informal={informal}",
            f"question={q}",
            "expected=yes",
        ])
        if rc == 0:
            mined += 1
    print(f"mined {mined} review point(s) from {slug} disagreements")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p_i = sub.add_parser("init"); p_i.add_argument("slug"); p_i.add_argument("informal")
    p_r = sub.add_parser("render"); p_r.add_argument("slug"); p_r.add_argument("id")
    p_r.add_argument("module"); p_r.add_argument("theorem")
    p_c = sub.add_parser("check"); p_c.add_argument("slug")
    p_c.add_argument("--lean-dir", default="lean")
    p_c.add_argument("--lemmas", default=None,
                     help="optional JSON file mapping 'idA|idB' -> proved IFF lemma FQN")
    p_m = sub.add_parser("mine"); p_m.add_argument("slug")
    args = ap.parse_args()

    if args.cmd == "init":
        return init(args.slug, args.informal)
    if args.cmd == "render":
        return render(args.slug, args.id, args.module, args.theorem)
    if args.cmd == "check":
        import json as _json
        lemmas = None
        if args.lemmas:
            lemmas = _json.loads(Path(args.lemmas).read_text(encoding="utf-8"))
        return check(args.slug, Path(args.lean_dir), lemmas)
    if args.cmd == "mine":
        return mine(args.slug)
    return 2


if __name__ == "__main__":
    sys.exit(main())