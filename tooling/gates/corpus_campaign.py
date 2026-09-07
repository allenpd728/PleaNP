#!/usr/bin/env python3
"""Gate 3 corpus campaign driver -- measured multi-rendering evidence (#19).

Runs the multi-rendering loop (`multi_render check --lemmas` + `mine`) over a
corpus of campaign workspaces (each `churn/<slug>/` holds >= 2 independent
Lean renderings of one informal claim), then collates a JSON/CSV summary a
grant panel can read: N renderings, machine-equivalence rate, disagreements
surfaced, mined review points, dedupe accounting.

Duplicate-issue accounting (#19 DoD): the sync workflow files one GitHub issue per
pending YAML on push. Re-running `mine` on a campaign whose disagreements
were already surfaced previously would re-file the same points. The driver
therefore reports `mined` (this run) plus `mined_historical` (from an
optional `--previously-mined <slug>:<n>` mapping, e.g. `bgs:5` -- the
5 points filed in commit fbf2f6a, swept as issues #7-#16/#20), and the
`--skip-mine` flag for campaigns whose disagreements should not be re-mined.



Stdlib-only (subprocess, json, csv, argparse); no Lean needed at of run
(Lean runs happen via `multi_render.check`)).
"""
from __future__ import annotations

import argparse
import csv
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHURN = ROOT / "churn"
MULTI = Path(__file__).resolve().parent / "multi_render.py"


def _load_matrix(slug: str) -> dict:
    p = CHURN / slug / "matrix.json"
    if not p.exists():
        return {"slug": slug, "pairs": []}
    return json.loads(p.read_text(encoding="utf-8"))


def _counts(slug: str, matrix: dict) -> dict:
    pairs = matrix.get("pairs", [])
    total = len(pairs)
    equiv = sum(1 for p in pairs if p.get("equivalent"))
    regs = CHURN / slug / "renderings"
    n_renderings = len(list(regs.glob("*.json"))) if regs.is_dir() else 0
    return {"renderings": n_renderings,
            "pairs": total, "equivalent": equiv, "disagree": total - equiv}


def _count_review_points(slug: str) -> int:
    """Count pending+confirmed+flagged review files carryingthe campaign's run key."""
    rdir = ROOT / "reviews"
    run_key = f"multi-rendering-{slug}"
    n = 0
    for sub in ("pending", "confirmed", "flagged"):
        d = rdir / sub
        if not d.is_dir():
            continue
        for f in d.glob("*.yaml"):
            try:
                txt = f.read_text(encoding="utf-8")
                ok = f"run: {run_key}" in txt
            except Exception:
                ok = False
            if ok:
                n += 1
    return n


def run_campaign(slug: str, lean_dir: Path, mine: bool,
                  previously_mined: int = 0) -> dict:

    """Run check (+mine unless skipped); collate the summary for one slug."""
    churn_p = CHURN / slug
    lemmas = churn_p / "lemmas.json"
    args = [sys.executable, str(MULTI), "check", slug,
            "--lean-dir", str(lean_dir.resolve())]
    if lemmas.exists():
        args += ["--lemmas", str(lemmas)]
    r = subprocess.run(args, capture_output=True, text=True, cwd=str(ROOT))
    if r.returncode != 0:
        detail = (r.stdout or "") + (r.stderr or "")
        return {"slug": slug, "error": detail[-500:], "renderings": 0,
                "pairs": 0, "equivalent": 0, "disagree": 0,
                "mined_review_points": 0, "previously_mined": previously_mined,
                "skipped_mine": not mine}
    if mine:
        subprocess.run(
            [sys.executable, str(MULTI), "mine", slug],
            capture_output=True, text=True, cwd=str(ROOT))
    m = _load_matrix(slug)
    c = _counts(slug, m)
    return {"slug": slug, **c,
            "mined_review_points": _count_review_points(slug) if mine else 0,
            "previously_mined": previously_mined,
            "skipped_mine": not mine,
            "matrix": f"churn/{slug}/matrix.json"}


def main() -> int:

    epilog = ("e.g.: python3 tooling/gates/corpus_campaign.py bgs barrier-verdict "
                "--skip-mine --previously-mined bgs:5")
    ap = argparse.ArgumentParser(description=__doc__,
                                 epilog=epilog,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("slugs", nargs="+", help="campaign slugs, e.g. bgs barrier-verdict")
    ap.add_argument("--lean-dir", default="lean", type=Path,
                    help="path to the lake root (default: lean)")
    ap.add_argument("--skip-mine", action="store_true",
                    help="Do not run `mine` (e.g. for campaigns whose disagreements "
                         "were already surfaced previously)")
    ap.add_argument("--previously-mined", default="", metavar="SLUG:N",
                    help="comma-separated 'slug:count' of review points filed historically, "
                         "accounted for in the summary (e.g. bgs:5)")
    ap.add_argument("--out", default="tooling/gates/corpus_campaign.json",
                    help="output JSON path (default: tooling/gates/corpus_campaign.json)")
    ap.add_argument("--csv", default=None, help="optional CSV output path")
    args = ap.parse_args()

    prev = {}
    if args.previously_mined:
        for item in args.previously_mined.split(","):
            if ":" in item:
                s, n = item.rsplit(":", 1)
                prev[s.strip()] = int(n)
    rows = []
    for slug in args.slugs:
        mine = not args.skip_mine
        rows.append(run_campaign(slug, args.lean_dir, mine=mine,
                                previously_mined=prev.get(slug, 0)))
    total_renderings = sum(r.get("renderings", 0) for r in rows)

    total_pairs = sum(r.get("pairs", 0) for r in rows)
    total_equiv = sum(r.get("equivalent", 0) for r in rows)
    total_disagree = sum(r.get("disagree", 0) for r in rows)
    total_mined = sum(r.get("mined_review_points", 0) for r in rows)
    total_prev_mined = sum(r.get("previously_mined", 0) for r in rows)
    summary = {"generated": _now(),
               "corpus": {r["slug"]: r for r in rows},
               "totals": {"claims": len(rows), "renderings": total_renderings,
                          "pairs": total_pairs, "equivalent": total_equiv,
                          "disagree": total_disagree,
                          "mined_this_run": total_mined,
                          "mined_historical": total_prev_mined}}
    out = Path(args.out)
    out.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    if args.csv:
        with open(args.csv, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(["slug", "renderings", "pairs", "equivalent", "disagree",
                        "mined_this_run", "mined_historical", "skipped_mine"])
            for r in rows:
                w.writerow([r["slug"], r["renderings"], r["pairs"], r["equivalent"],
                           r["disagree"], r["mined_review_points"], r["previously_mined"],
                           r["skipped_mine"]])
    print(json.dumps({"totals": summary["totals"]}, indent=2))
    return 0


def _now() -> str:
    import datetime as _dt
    return _dt.datetime.now(_dt.timezone.utc).isoformat()


if __name__ == "__main__":
    sys.exit(main())
