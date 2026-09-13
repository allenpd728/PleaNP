#!/usr/bin/env python3
"""Galaxy data layer — extract negative-space artifacts into the Galaxy model.

Per issue #86 and the Galaxy spec (docs/STATEMENTS/Galaxy.spec.md §3–4): reads
the repo's existing negative-space artifacts and produces a structured Galaxy
data model (black holes, event horizons, asteroids) that the renderer
consumes. Pure stdlib (repo convention): no network, no third-party yaml, no
Lean. This is a tooling layer over repo artifacts — NOT Lean code, NOT a gate,
NOT a claim.

Gate-color taxonomy (spec §3): DEAD=red, vacuity=amber, model=blue,
read-back=purple, hygiene=green, unresolved=grey.

Usage:
    python3 galaxy_data.py --repo ../.. --json galaxy.json
    python3 galaxy_data.py --repo ../.. --pretty
    python3 galaxy_data.py --repo ../.. --table
"""
from __future__ import annotations

import argparse
import datetime
import json
import re
from dataclasses import dataclass, field
from pathlib import Path

from miniyaml import loads as loads_yaml

# --------------------------------------------------------------------------
# Gate-color taxonomy (spec §3) — shared with the renderer.
# --------------------------------------------------------------------------
GATE_COLORS = {
    "dead": "#e5484d",       # DEAD (barrier-check verdict)
    "vacuity": "#f2b544",    # Gate 5 vacuity / non-triviality
    "model": "#3e7bfa",      # Gate 2 model-consistency
    "readback": "#b45be6",   # Gate 4 read-back / Gate 3 rendering fidelity
    "hygiene": "#30a46c",    # Gate 6/8 hygiene/unicode (sorries)
    "unresolved": "#8d8d8d",  # open / unclassified
}
GATE_ORDER = ("dead", "vacuity", "model", "readback", "hygiene", "unresolved")

BARRIER_NAMES = ("Relativization", "NaturalProofs", "Algebrization")
_BARRIER_BY_SUBSTR = (
    ("relativiz", "Relativization"),
    ("bgs", "Relativization"),
    ("natural proof", "NaturalProofs"),
    ("razborov", "NaturalProofs"),
    ("algebriz", "Algebrization"),
)


# --------------------------------------------------------------------------
# Data model — dataclasses; to_dict() is the model the renderer consumes.
# --------------------------------------------------------------------------
@dataclass
class Barrier:
    name: str
    description: str = ""
    declarations: list = field(default_factory=list)
    declarations_meta: list = field(default_factory=list)

    def to_dict(self) -> dict:
        declared = [dm["declaration"] for dm in self.declarations_meta]
        return {"name": self.name, "description": self.description,
                "declarations": declared or list(self.declarations),
                "declarations_meta": list(self.declarations_meta)}


@dataclass
class Horizon:
    barrier: str
    proven: list = field(default_factory=list)     # statements fully proven
    rendered: list = field(default_factory=list)   # rendered, not yet proven
    boundary: list = field(default_factory=list)   # provability-boundary statements

    def to_dict(self) -> dict:
        return {"barrier": self.barrier, "proven": list(self.proven),
                "rendered": list(self.rendered), "boundary": list(self.boundary)}


@dataclass
class Asteroid:
    label: str
    gate: str = "unresolved"
    detail: str = ""
    radius: float = 1.0
    source: str = ""
    declarations: list = field(default_factory=list)

    def to_dict(self) -> dict:
        return {"label": self.label, "gate": self.gate,
                "color": GATE_COLORS.get(self.gate, GATE_COLORS["unresolved"]),
                "detail": self.detail, "radius": self.radius,
                "source": self.source, "declarations": list(self.declarations)}


@dataclass
class Galaxy:
    barriers: list = field(default_factory=list)
    horizons: list = field(default_factory=list)
    asteroids: list = field(default_factory=list)
    metadata: dict = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {"barriers": [b.to_dict() for b in self.barriers],
                "horizons": [h.to_dict() for h in self.horizons],
                "asteroids": [a if isinstance(a, dict) else a.to_dict()
                              for a in self.asteroids],
                "metadata": dict(self.metadata)}


# --------------------------------------------------------------------------
# Parsers — each reads one repo artifact and returns dataclasses/dicts.
# --------------------------------------------------------------------------
def parse_barriers(yaml_text: str) -> list[Barrier]:
    """From formalization.yaml → the three barrier families.

    Primary source is ``status.main_results`` (rendered declarations); the
    ``alignment.statements`` list contributes declaration → source rows that
    mention a barrier family; ``sources`` provide the informal barrier titles.
    Barriers with no concrete Lean declaration still appear (rendered as
    family-level skeletons) so the galaxy always shows all three black holes.
    """
    data = loads_yaml(yaml_text)
    results = data.get("status", {}).get("main_results", []) or data.get("main_results", [])
    statements = data.get("alignment", {}).get("statements", []) or []
    sources = data.get("sources", []) or []

    by_name: dict[str, Barrier] = {n: Barrier(name=n) for n in BARRIER_NAMES}

    for r in results:
        if not isinstance(r, dict):
            continue
        desc = str(r.get("description", "")) or ""
        decl = str(r.get("declaration", "")).strip()
        key = _barrier_key(desc) or (_barrier_key(decl) if decl else None)
        if key is None:
            continue
        b = by_name[key]
        if desc.strip():
            b.description = desc.strip()
        if decl:
            b.declarations_meta.append({
                "declaration": decl,
                "status": str(r.get("status", "")).strip(),
                "file": str(r.get("file", "")).strip(),
                "sorry_count": r.get("sorry_count", 0),
            })

    for s in statements:
        if not isinstance(s, dict):
            continue
        source = str(s.get("source", "")) or ""
        decl = str(s.get("lean", "")).strip()
        key = _barrier_key(source) or (_barrier_key(decl) if decl else None)
        if key is None:
            continue
        b = by_name[key]
        if source.strip() and not b.description:
            b.description = source.strip()
        if decl:
            meta = [m for m in b.declarations_meta if m["declaration"] == decl]
            if not meta:
                b.declarations_meta.append({
                    "declaration": decl,
                    "status": str(s.get("status", "")).strip(),
                    "file": str(s.get("module", "")).strip(),
                    "sorry_count": 0,
                })

    for s in sources:
        if not isinstance(s, dict):
            continue
        title = str(s.get("title", "")) or ""
        key = _barrier_key(title)
        if key is not None and not by_name[key].description:
            by_name[key].description = title.strip()

    return [by_name[k] for k in BARRIER_NAMES]


def _barrier_key(desc: str) -> str | None:
    low = desc.lower()
    for needle, name in _BARRIER_BY_SUBSTR:
        if needle in low:
            return name
    return None


def parse_matrix(matrix_json: dict) -> list[dict]:
    """From a churn/*/matrix.json BLOCKED pair set → asteroids.

    An ``equivalent: false`` pair is an asteroid: the renderings could not be
    machine-verified equivalent (Gate 3 statement-fidelity).
    """
    asteroids = []
    pairs = matrix_json.get("pairs", [])
    slug = matrix_json.get("slug", "?")
    for p in pairs:
        if not p.get("equivalent", True):
            a, b = p.get("a", "?"), p.get("b", "?")
            detail = p.get("detail", "")
            asteroids.append({
                "label": f"{slug}: {a} ≢ {b}",
                "gate": "readback",
                "detail": detail,
                "radius": 1.0,
                "source": f"churn/{slug}/matrix.json",
                "declarations": [],
            })
    return asteroids


def parse_blockers(blockers_dir: Path) -> list[dict]:
    """From blockers/*.md → asteroids (spec-level gaps; gate=model)."""
    asteroids = []
    if not blockers_dir.is_dir():
        return asteroids
    for f in sorted(blockers_dir.glob("*.md")):
        text = f.read_text(encoding="utf-8")
        m = re.search(r"^#\s+Blocker:\s*([^\n]+)", text, re.MULTILINE)
        label = m.group(1).strip() if m else f.name
        mdate = re.search(r"(\d{8})-(\d{4})", f.name)
        radius = 1.4
        if mdate:
            radius = 1.0 + (int(mdate.group(1)[-2:]) % 6) / 6.0
        detail = ""
        mres = re.search(r"## Resolution\s*\n(.*?)(?:\n## |\Z)", text, re.DOTALL)
        if mres and mres.group(1).strip():
            detail = " ".join(mres.group(1).strip().splitlines())[:200]
        else:
            mw = re.search(r"## What information is missing\s*\n(.*?)(?:\n## |\Z)",
                           text, re.DOTALL)
            if mw:
                detail = " ".join(mw.group(1).strip().splitlines())[:200]
        asteroids.append({
            "label": f"blocker: {label}",
            "gate": "model",
            "detail": detail or f"Spec-level blocker ({f.name})",
            "radius": radius,
            "source": f.name,
            "declarations": [],
        })
    return asteroids


def parse_sorries(tracker_md: str) -> list[dict]:
    """From docs/SORRY_TRACKER.md rows → asteroids (hygiene debt)."""
    asteroids = []
    for line in tracker_md.splitlines():
        line = line.strip()
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) < 5:
            continue
        number = cells[0].strip("#")
        what = cells[1].strip("`")
        pending_cell = cells[3].strip()
        if not number.isdigit() or not pending_cell:
            continue
        detail = f"{cells[2].strip()} — pending: {pending_cell}"
        status = cells[-1].strip() if len(cells) >= 6 else ""
        if status and status not in ("Priority", "Medium", "Low", "High"):
            detail += f" [{status}]"
        decl = ""
        m = re.search(r"([A-Za-z][\w.]*\.[A-Za-z_]\w*|[A-Za-z_]\w+\.lean:\d+)", cells[2])
        if m:
            decl = m.group(1)
        asteroids.append({
            "label": f"sorry: {what or number}",
            "gate": "hygiene",
            "detail": detail[:300],
            "radius": 0.75,
            "source": "docs/SORRY_TRACKER.md",
            "declarations": [decl] if decl else [f"#{number}"],
        })
    return asteroids


def parse_review_points(dir_path: Path) -> list[dict]:
    """From reviews/pending/*.yaml → asteroids (semantic-review pending)."""
    asteroids = []
    if not dir_path.is_dir():
        return asteroids
    for f in sorted(dir_path.glob("*.yaml")):
        text = f.read_text(encoding="utf-8")
        claim = ""
        m = re.search(r"^claim:\s*(.+)$", text, re.MULTILINE)
        if m:
            claim = m.group(1).strip().strip("'\"")
        detail = ""
        mq = re.search(r"^question:\s*[\"']?(.+?)[\"']?\s*$", text, re.MULTILINE)
        if mq:
            detail = mq.group(1).strip()
        decl = ""
        md = re.search(r"^decl:\s*(.+)$", text, re.MULTILINE)
        if md:
            decl = md.group(1).strip().strip("'\"")
        asteroids.append({
            "label": f"review: {claim[:70] or f.name}",
            "gate": "readback",
            "detail": detail,
            "radius": 0.9,
            "source": f"reviews/pending/{f.name}",
            "declarations": [decl] if decl else [],
        })
    return asteroids


# --------------------------------------------------------------------------
# Assembly — the fully wired Galaxy model built from the repo's live artifacts.
# --------------------------------------------------------------------------
def build_galaxy(repo_root: Path, metadata: dict | None = None) -> Galaxy:
    """Assemble holes/horizons/asteroids from the repo at repo_root."""

    # --- black holes (barriers) ---
    yaml_path = repo_root / "formalization.yaml"
    barriers = []
    if yaml_path.exists():
        barriers = parse_barriers(yaml_path.read_text(encoding="utf-8"))
    if not barriers:
        barriers = [Barrier(name=n, description="(no formalization.yaml main_results)")
                    for n in BARRIER_NAMES]

    # --- event horizons (near-statement lattice) ---
    boundary_rows = _load_boundary(repo_root)
    horizons = []
    for b in barriers:
        h = Horizon(barrier=b.name)
        for dm in b.declarations_meta:
            status = dm["status"]
            if "validated" in status or "proved" in status:
                h.proven.append(dm["declaration"])
            else:
                h.rendered.append(dm["declaration"])
        for row in boundary_rows:
            if row["barrier"] == b.name:
                if row["proven"] and row["declaration"] not in h.proven:
                    h.proven.append(row["declaration"])
                elif not row["proven"] and row["declaration"] not in h.boundary:
                    h.boundary.append(row["declaration"])
        horizons.append(h)

    # --- asteroids (failed / blocked artifacts) ---
    asteroids: list = []
    churn_dir = repo_root / "churn"
    if churn_dir.is_dir():
        for mf in sorted(churn_dir.glob("*/matrix.json")):
            try:
                data = json.loads(mf.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                continue
            asteroids.extend(parse_matrix(data))
    asteroids.extend(parse_blockers(repo_root / "blockers"))
    if (repo_root / "docs" / "SORRY_TRACKER.md").exists():
        asteroids.extend(parse_sorries(
            (repo_root / "docs" / "SORRY_TRACKER.md").read_text(encoding="utf-8")))
    asteroids.extend(parse_review_points(repo_root / "reviews" / "pending"))
    # Normalize: every asteroid carries its gate color (the renderer consumes
    # plain dicts; dataclass to_dict() already injects color).
    for a in asteroids:
        if isinstance(a, dict):
            a["color"] = GATE_COLORS.get(a.get("gate", "unresolved"),
                                         GATE_COLORS["unresolved"])

    meta = {
        "repo": str(repo_root),
        "generated": datetime.datetime.now().isoformat(timespec="seconds"),
        "generator": "galaxy_data.build_galaxy (stdlib; issue #86)",
        **(metadata or {}),
        "barrier_names": [b.name for b in barriers],
        "horizon_count": len(horizons),
        "asteroid_count": len(asteroids),
        "gate_colors": dict(GATE_COLORS),
    }
    return Galaxy(barriers=barriers, horizons=horizons, asteroids=asteroids,
                  metadata=meta)


def _load_boundary(repo_root: Path) -> list[dict]:
    """Load the near-statement lattice (provability boundary) from churn/boundary."""
    out = []
    result_md = repo_root / "churn" / "boundary" / "result.md"
    if not result_md.exists():
        return out
    for line in result_md.read_text(encoding="utf-8").splitlines():
        m = re.match(r"\|\s*(N\d+)\s*\|\s*([^|]+)\s*\|\s*([^|]+)\s*\|\s*(.+?)\s*\|", line)
        if not m:
            continue
        label, statement, kind, verdict = (m.group(i).strip() for i in range(1, 5))
        # Handle the table's "✅ PROVEN (...)" vs "⛔ NOT PROVEN (...)" verdict cells.
        verdict_head = verdict.upper().split("(")[0]
        proven = "PROVEN" in verdict_head and "NOT PROVEN" not in verdict_head
        barrier = _barrier_key(statement) or "Relativization"
        tag = f"{label} — {statement} [{kind}]"
        out.append({"label": label, "statement": statement, "kind": kind,
                    "proven": proven, "declaration": tag, "barrier": barrier})
    return out


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------
def resolve_repo(path: str) -> Path:
    p = Path(path).resolve()
    if (p / "formalization.yaml").exists():
        return p
    return Path(__file__).resolve().parent.parent.parent


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--repo", default=".", help="PleaNP repo root")
    ap.add_argument("--json", help="write the Galaxy model as JSON to this path")
    ap.add_argument("--pretty", action="store_true", help="print a JSON dump")
    ap.add_argument("--table", action="store_true", help="print a summary table")
    args = ap.parse_args(argv)

    galaxy = build_galaxy(resolve_repo(args.repo))
    if args.json:
        out = Path(args.json)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(galaxy.to_dict(), indent=2, ensure_ascii=False),
                       encoding="utf-8")
        print(f"wrote {out}")
    if args.pretty:
        print(json.dumps(galaxy.to_dict(), indent=2, ensure_ascii=False))
    if args.table:
        print_table(galaxy)
    if not (args.json or args.pretty or args.table):
        print(f"Galaxy: {len(galaxy.barriers)} barriers, {len(galaxy.horizons)} horizons, "
              f"{len(galaxy.asteroids)} asteroids")
    return 0


def print_table(galaxy: Galaxy) -> None:
    print(f"# Galaxy — {len(galaxy.barriers)} barriers, {len(galaxy.asteroids)} asteroids\n")
    for b in galaxy.barriers:
        print(f"## {b.name}")
        for dm in b.declarations_meta:
            print(f"  - `{dm['declaration']}` [{dm['status']}]")
    print("\n## Horizons")
    for h in galaxy.horizons:
        print(f"- {h.barrier}: proven={len(h.proven)} rendered={len(h.rendered)} "
              f"boundary={len(h.boundary)}")
    print("\n## Asteroids")
    for a in galaxy.asteroids:
        a_dict = a if isinstance(a, dict) else a.to_dict()
        print(f"- {a_dict['label']}  [{a_dict['gate']}] {a_dict['detail'][:100]}")


if __name__ == "__main__":
    raise SystemExit(main())