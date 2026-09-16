#!/usr/bin/env python3
"""Review inbox — the NON-BLOCKING, async interface for human semantic review.

Design (docs/REVIEW_INBOX.md): the human confirmation at the irreducible
semantic hop must NOT block multi-agent work. Agents write a review point
(one plain-language yes/no question per claim) and CONTINUE — they never
wait. The human reads a single generated INBOX (batched, oldest-first) and
answers whenever convenient. Flagged points re-open the claim
retrospectively (matching the existing retrospective-on-dev model); nothing
stalls.

Layout:
    reviews/pending/<id>.yaml     awaiting the human
    reviews/confirmed/<id>.yaml   human confirmed the machine summary matches
    reviews/flagged/<id>.yaml     human flagged a mismatch -> claim reopens
    reviews/INBOX.md              GENERATED index (the human reads this)

A review point is YAML with an exact schema (see _POINT_SCHEMA). One file =
one claim = ONE question.

Commands:
    review_inbox.py add     <fields...>       create a pending point
    review_inbox.py index                     regenerate reviews/INBOX.md
    review_inbox.py confirm <id>              move pending -> confirmed
    review_inbox.py flag    <id> [reason]     move pending -> flagged
    review_inbox.py list    [--status s]      print points (default pending)

The tool is stdlib-only (a tiny YAML-subset loader); no network, no Lean,
no LLM — it is a file-and-doc interface that any agent writes to and the
human reads from.

Exit codes: 0 ok, 1 error (bad point / unknown id / conflict), 2 usage.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REVIEWS = ROOT / "reviews"
PENDING = REVIEWS / "pending"
CONFIRMED = REVIEWS / "confirmed"
FLAGGED = REVIEWS / "flagged"
INBOX = REVIEWS / "INBOX.md"

_ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")

# The exact set of allowed fields (agents must not invent new ones).
_POINT_SCHEMA = {
    "kind",            # always "semantic-review"
    "run",             # run-id (e.g. 20260906-1530-a1b2)
    "agent",           # agent name
    "created",         # ISO-8601 UTC timestamp
    "claim",           # short human title of the claim
    "module",          # Lean module(s)
    "decl",            # fully-qualified declaration name
    "machine_summary", # English shape summary (from statement_lint / read-back)
    "informal",        # the step-0 informal claim
    "question",        # ONE plain-language yes/no question for the human
    "expected",        # the answer the agent asserts ("yes" or "no")
    "refs",            # optional; commit hash / issue link
    "spec",            # optional; path to a rendering-disagreement spec JSON (renders the probe checklist in the index)
    "reason",          # optional; set only when flagged
    "resolution",      # optional; free-text resolution/provenance note (preserved through confirm/flag round-trips)
    "status",          # pending | confirmed | flagged (managed by the tool)
}

_REQUIRED = {"kind", "run", "agent", "created", "claim", "module", "decl",
             "machine_summary", "informal", "question", "expected"}

# Load-bearing token pairs used to build recheck-control twins (perturbations).
# Flipping one of these changes the claim's meaning — a control twin should be
# FLAGGED, so confirming it is a fatigue signal.
_PERTURB_PAIRS = [
    ("for every", "there exists"),
    ("∀", "∃"),
    ("⊆", "⊇"),
    ("subset", "superset"),
    ("containment", "reverse containment"),
    ("equality (=)", "inequality (≠)"),
    ("equals", "does not equal"),
]


def _flip(text: str) -> tuple[str, str]:
    """Flip the first load-bearing token found in `text`.
    Returns (flipped_text, description_of_what_was_flipped)."""
    for a, b in _PERTURB_PAIRS:
        if a in text:
            return text.replace(a, b, 1), f"'{a}' -> '{b}'"
        if b in text:
            return text.replace(b, a, 1), f"'{b}' -> '{a}'"
    return text, "expected-answer flipped (no load-bearing token found)"


class _MiniYaml:
    """Minimal YAML-subset reader/writer for our flat schema (no deps)."""

    @staticmethod
    def dump(d: dict) -> str:
        out = []
        for k in sorted(d):
            v = d[k]
            if v is None:
                continue
            if isinstance(v, bool):
                v = "true" if v else "false"
            s = str(v).strip()
            if "\n" in s or ":" in s or s == "":
                s = '"' + s.replace('"', '\\"') + '"'
            out.append(f"{k}: {s}")
        return "\n".join(out) + "\n"

    @staticmethod
    def load(text: str) -> dict:
        d = {}
        for line in text.splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if ":" not in line:
                raise ValueError(f"bad line: {line!r}")
            k, _, v = line.partition(":")
            k = k.strip()
            v = v.strip()
            if v.startswith('"') and v.endswith('"') and len(v) >= 2:
                v = v[1:-1].replace('\\"', '"')
            d[k] = v
        return d


def _id() -> str:
    now = _dt.datetime.now(_dt.timezone.utc)
    # Unique-per-second plus a short random suffix to avoid collisions when
    # multiple agents add in the same second (parallel multistream safety).
    import secrets
    return now.strftime("%Y%m%d-%H%M%S") + "-" + secrets.token_hex(2)


def _point_path(pid: str, status: str) -> Path:
    return dict(pending=PENDING, confirmed=CONFIRMED, flagged=FLAGGED)[status] / f"{pid}.yaml"


def _find(pid: str) -> tuple[Path | None, str | None]:
    for st in ("pending", "confirmed", "flagged"):
        p = _point_path(pid, st)
        if p.exists():
            return p, st
    return None, None


def add(fields: list[str]) -> int:
    d = {}
    for tok in fields:
        if "=" not in tok:
            print(f"error: field must be key=value (got {tok!r})", file=sys.stderr)
            return 2
        k, _, v = tok.partition("=")
        if k not in _POINT_SCHEMA:
            print(f"error: unknown field {k!r} (allowed: {sorted(_POINT_SCHEMA)})",
                  file=sys.stderr)
            return 2
        d[k] = v
    missing = _REQUIRED - set(d)
    if missing:
        print(f"error: missing required fields: {sorted(missing)}", file=sys.stderr)
        return 2
    if d["kind"] != "semantic-review":
        print("error: kind must be 'semantic-review'", file=sys.stderr)
        return 2
    d["status"] = "pending"
    pid = _id()
    PENDING.mkdir(parents=True, exist_ok=True)
    path = PENDING / f"{pid}.yaml"
    path.write_text(_MiniYaml.dump(d), encoding="utf-8")
    try:
        shown = path.relative_to(ROOT)
    except ValueError:
        shown = path
    print(f"added pending review point: {pid} -> {shown}")
    return 0


def _move(pid: str, target: str, reason: str | None) -> int:
    if not _ID_RE.match(pid or ""):
        print(f"error: bad point id {pid!r}", file=sys.stderr)
        return 2
    path, st = _find(pid)
    if path is None:
        print(f"error: no review point with id {pid!r}", file=sys.stderr)
        return 1
    if st == target:
        print(f"info: {pid} already {target}")
        return 0
    d = _MiniYaml.load(path.read_text(encoding="utf-8"))
    d["status"] = target
    if reason:
        d["reason"] = reason
    if target == "confirmed":
        d["confirmed_at"] = _dt.datetime.now(_dt.timezone.utc).isoformat()
    (CONFIRMED if target == "confirmed" else FLAGGED).mkdir(parents=True, exist_ok=True)
    final = _point_path(pid, target)
    final.write_text(_MiniYaml.dump(d), encoding="utf-8")
    path.unlink(missing_ok=True)
    print(f"{target} {pid} (was {st})")

    # AUTO-REQUEUE: if a recheck-control was CONFIRMED (fatigue signal: it
    # should have been flagged), re-file the original claim as a fresh
    # pending point so no sweep is needed. Nothing is silent: the re-queued
    # point records `reopened_by=<control-id>`, and the control stays in the
    # confirmed/flagged archive as the audit record.
    if target == "confirmed" and d.get("kind") == "recheck-control" and d.get("control_of"):
        orig_path, _ = _find(d["control_of"])
        if orig_path is not None:
            orig = _MiniYaml.load(orig_path.read_text(encoding="utf-8"))
        else:
            orig = None
        if orig is None:
            # Control references a point we no longer track — reconstruct a
            # fresh pending from the control's own fields (claim/question).
            orig = d
        fresh = dict(orig)
        for k in ("status", "confirmed_at", "reason", "kind", "control_of", "reopened_by"):
            fresh.pop(k, None)
        fresh["kind"] = "semantic-review"
        fresh["created"] = _dt.datetime.now(_dt.timezone.utc).isoformat()
        fresh["reopened_by"] = pid
        fresh["status"] = "pending"
        fresh["question"] = (fresh.get("question", "") +
                             " [AUTO-REQUEUED after a confirmed recheck-control; "
                             "please review carefully.]")
        new_id = _id()
        PENDING.mkdir(parents=True, exist_ok=True)
        (PENDING / f"{new_id}.yaml").write_text(_MiniYaml.dump(fresh), encoding="utf-8")
        print(f"AUTO-REQUEUE: re-filed original {d['control_of']} as {new_id} "
              f"(control {pid} was confirmed — fatigue signal)")
    return 0


def perturb(pid: str) -> int:
    """Create a recheck-control twin of a CONFIRMED point: same claim with one
    load-bearing element flipped. The twin should be FLAGGED — confirming it is
    a fatigue signal (the human rubber-stamped the original).

    This is the "second async review that changes the content" (fatigue
    protection). Disclosed honestly in the twin's question: the control exists,
    is not marked in advance, and confirming it re-queues the original.
    """
    if not _ID_RE.match(pid or ""):
        print(f"error: bad point id {pid!r}", file=sys.stderr)
        return 2
    path, st = _find(pid)
    if path is None or st != "confirmed":
        print(f"error: {pid!r} not found / not confirmed (need a confirmed point)",
              file=sys.stderr)
        return 1
    orig = _MiniYaml.load(path.read_text(encoding="utf-8"))
    summary_flipped, what = _flip(orig.get("machine_summary", ""))
    twin = dict(orig)
    twin["kind"] = "recheck-control"
    twin["control_of"] = pid
    twin["created"] = _dt.datetime.now(_dt.timezone.utc).isoformat()
    twin["machine_summary"] = summary_flipped
    twin["expected"] = "no" if orig.get("expected") == "yes" else "yes"
    twin["question"] = (
        f"RECHECK-CONTROL of {pid}: you confirmed the original. This twin has "
        f"[{what}] flipped. It should be FLAGGED — confirming it indicates "
        f"possible fatigue and re-queues the original.")
    twin["status"] = "pending"
    # drop control-specific fields that shouldn't copy
    twin.pop("confirmed_at", None)
    twin.pop("reason", None)
    new_id = _id()
    PENDING.mkdir(parents=True, exist_ok=True)
    (PENDING / f"{new_id}.yaml").write_text(_MiniYaml.dump(twin), encoding="utf-8")
    print(f"recheck-control {new_id} created from confirmed {pid} (flipped: {what})")
    return 0


def requeue(orig_id: str) -> int:
    """Re-file a confirmed ORIGINAL point as a fresh pending point (auto-
    requeue after a confirmed recheck-control). Used by the GH workflow so
    no sweep is needed. Mirrors the auto-requeue block in _move."""
    if not _ID_RE.match(orig_id or ""):
        print(f"error: bad point id {orig_id!r}", file=sys.stderr)
        return 2
    orig_path, st = _find(orig_id)
    if orig_path is None:
        # Original no longer tracked (e.g. it was excluded); nothing to redo.
        print(f"info: original {orig_id} not found (state {st}); nothing to re-queue")
        return 0
    orig = _MiniYaml.load(orig_path.read_text(encoding="utf-8"))
    fresh = dict(orig)
    for k in ("status", "confirmed_at", "reason", "kind", "control_of", "reopened_by"):
        fresh.pop(k, None)
    fresh["kind"] = "semantic-review"
    fresh["created"] = _dt.datetime.now(_dt.timezone.utc).isoformat()
    fresh["reopened_by"] = "auto-requeue"
    fresh["status"] = "pending"
    fresh["question"] = (fresh.get("question", "") +
                         " [AUTO-REQUEUED after a confirmed recheck-control; "
                         "please review carefully.]")
    new_id = _id()
    PENDING.mkdir(parents=True, exist_ok=True)
    (PENDING / f"{new_id}.yaml").write_text(_MiniYaml.dump(fresh), encoding="utf-8")
    print(f"AUTO-REQUEUE: re-filed original {orig_id} as {new_id}")
    return 0


def fatigue() -> int:
    """Report fatigue signals: confirmed points whose recheck-control twin the
    human also confirmed (the rubber-stamp signal), and very-fast confirms."""
    controls = 0
    confirmed_controls = []
    for p in sorted(CONFIRMED.glob("*.yaml")):
        d = _load_or_none(p)
        if d.get("kind") == "recheck-control":
            controls += 1
            confirmed_controls.append(p.stem)
    # fast-confirm heuristic: original confirmed within 30s of its created time
    fast = []
    for p in sorted(CONFIRMED.glob("*.yaml")):
        if p.stem in confirmed_controls:
            continue
        d = _load_or_none(p)
        created = d.get("created", "")
        conf_at = d.get("confirmed_at", "")
        try:
            import datetime
            c = datetime.datetime.fromisoformat(created)
            a = datetime.datetime.fromisoformat(conf_at)
            if (a - c).total_seconds() < 30:
                fast.append(p.stem)
        except Exception:
            pass
    print(f"recheck-controls confirmed by the human: {len(confirmed_controls)}"
          f"{' -> ' + ', '.join(confirmed_controls) if confirmed_controls else ''}")
    print(f"fast confirms (<30s): {len(fast)}{' -> ' + ', '.join(fast) if fast else ''}")
    if confirmed_controls or fast:
        print("ACTION: re-queue the originals of any confirmed recheck-controls;")
        print("consider pausing review for the fast-confirm author (fatigue).")
        return 1
    print("no fatigue signals detected.")
    return 0


def _import_probe_check():
    """Lazy-import the Gate-4 probe-checklist renderer (stdlib; avoids a hard
    dependency between the inbox and the gates tooling)."""
    gates_dir = Path(__file__).resolve().parents[2] / "tooling" / "gates"
    if str(gates_dir) not in sys.path:
        sys.path.insert(0, str(gates_dir))
    import probe_check
    return probe_check


def _spec_path(spec: str | None) -> Path | None:
    """Resolve a `spec` field to a file path, or None when absent/empty/
    literal `none` (the filing sentinel for no-spec)."""
    if not spec:
        return None
    if str(spec).strip().lower() == "none":
        return None
    return ROOT / str(spec)


def _render_point(pid: str, d: dict) -> str:
    lines = [
        f"### {pid}",
        f"- claim: {d.get('claim','')}",
        f"- decl: `{d.get('decl','')}`  (module: `{d.get('module','')}`)",
        f"- machine summary: {d.get('machine_summary','')}",
        f"- informal (what we wanted): {d.get('informal','')}",
        f"- **QUESTION: {d.get('question','')}**",
        f"- expected answer: {d.get('expected','')}",
        f"- run: `{d.get('run','')}`  agent: {d.get('agent','')}  created: {d.get('created','')}",
    ]
    if d.get("refs"):
        lines.append(f"- refs: {d['refs']}")
    spec = d.get("spec")
    spec_path = _spec_path(spec)
    if spec_path:
        try:
            pc = _import_probe_check()
            data = json.loads(spec_path.read_text(encoding="utf-8"))
            violations = pc.validate_rendering_disagreement_spec(data)
            if violations:
                lines.append("")
                lines.append(f"⚠️ spec failed probe-checklist validation: {'; '.join(violations)}")
            else:
                lines.append("")
                lines.append("Probe checklist (rendering disagreement):")
                lines.append("```")
                lines.append(pc.render_checklist(data))
                lines.append("```")
        except Exception as exc:
            lines.append("")
            lines.append(f"⚠️ could not render spec {spec!r}: {exc}")
    lines.append("")
    return "\n".join(lines)


def _load_or_none(p: Path) -> dict:
    try:
        return _MiniYaml.load(p.read_text(encoding="utf-8"))
    except Exception:
        return {"claim": p.stem}


def index() -> int:
    out = []
    out.append("# Review inbox (human review surface)")
    out.append("")
    out.append("> One review point = one claim = ONE question. Agents file points")
    out.append("> and never wait; you review the batch when convenient. `confirm`")
    out.append("> = the machine summary matches your intention; `flag` = it does")
    out.append("> not (the claim reopens). No answer blocks anyone.")
    out.append("")
    out.append("## Pending")
    out.append("")
    pend = sorted(PENDING.glob("*.yaml"))
    if not pend:
        out.append("_none_")
    for p in pend:
        out.append(_render_point(p.stem, _load_or_none(p)))
    out.append("## Confirmed")
    out.append("")
    conf = sorted(CONFIRMED.glob("*.yaml"))
    if conf:
        out.append("\n".join(f"- {p.stem}: {_load_or_none(p).get('claim','')}" for p in conf))
    else:
        out.append("_none_")
    out.append("")
    out.append("## Flagged")
    out.append("")
    flg = sorted(FLAGGED.glob("*.yaml"))
    if flg:
        out.append("\n".join(
            f"- {p.stem}: {_load_or_none(p).get('claim','')} — {_load_or_none(p).get('reason','')}"
            for p in flg))
    else:
        out.append("_none_")
    out.append("")
    out.append("---")
    out.append("How to answer: `python3 tooling/reviews/review_inbox.py confirm <id>`")
    out.append("or `flag <id> \"<reason>\"`. Agents sweep flagged points in their")
    out.append("next session (retrospective fix; nothing blocks).")
    out.append("")
    REVIEWS.mkdir(parents=True, exist_ok=True)
    INBOX.write_text("\n".join(out), encoding="utf-8")
    try:
        shown = INBOX.relative_to(ROOT)
    except ValueError:
        shown = INBOX
    print(f"wrote {shown}")
    return 0


def list_points(status: str | None) -> int:
    dirs = {"pending": PENDING, "confirmed": CONFIRMED, "flagged": FLAGGED}
    if status:
        dirs = {status: dirs[status]}
    for st, d in dirs.items():
        if not d.exists():
            continue
        for p in sorted(d.glob("*.yaml")):
            info = _load_or_none(p)
            print(f"[{st}] {p.stem}: {info.get('claim','')} (run {info.get('run','')})")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p_add = sub.add_parser("add", help="add a pending review point (key=value ...)")
    p_add.add_argument("fields", nargs="+")
    p_add.add_argument("--control", action="store_true",
                       help="file this as a recheck-control (kind=recheck-control)")
    sub.add_parser("index", help="regenerate reviews/INBOX.md")
    p_ok = sub.add_parser("confirm", help="confirm a pending point")
    p_ok.add_argument("id")
    p_fl = sub.add_parser("flag", help="flag a pending point (claim reopens)")
    p_fl.add_argument("id")
    p_fl.add_argument("reason", nargs="?", default=None)
    p_pt = sub.add_parser("perturb", help="make a recheck-control twin of a confirmed point")
    p_pt.add_argument("id")
    p_rq = sub.add_parser("requeue", help="re-file a confirmed original as a fresh pending point (auto-requeue)")
    p_rq.add_argument("id")
    sub.add_parser("fatigue", help="report fatigue signals (confirmed controls, fast confirms)")
    p_ls = sub.add_parser("list", help="list review points")
    p_ls.add_argument("--status", choices=["pending", "confirmed", "flagged"], default=None)
    args = ap.parse_args()

    if args.cmd == "add":
        if args.control:
            # force kind=recheck-control: drop any user-kind, append ours last
            args.fields = [f for f in args.fields if not f.startswith("kind=")]
            args.fields.append("kind=recheck-control")
        return add(args.fields)
    if args.cmd == "index":
        return index()
    if args.cmd == "confirm":
        return _move(args.id, "confirmed", None)
    if args.cmd == "flag":
        return _move(args.id, "flagged", args.reason)
    if args.cmd == "perturb":
        return perturb(args.id)
    if args.cmd == "requeue":
        return requeue(args.id)
    if args.cmd == "fatigue":
        return fatigue()
    if args.cmd == "list":
        return list_points(args.status)
    return 2


if __name__ == "__main__":
    sys.exit(main())