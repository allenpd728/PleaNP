#!/usr/bin/env python3
"""Gate: workflow-file integrity scan (`.github/workflows/*.yml`).

Why this exists (PleaNP #101 / #110). A repeated text-corruption signature was
found in the tree: content joined across a line boundary, or punctuation
absorbing the following space. It started as cosmetic comment damage in the
Rung-5 Lean files, but a later instance hit `.github/workflows/ci.yml` on `dev`
and was NOT cosmetic — three step boundaries had been swallowed into the
previous scalar, so GitHub would have rejected the entire workflow, and nothing
in the repo noticed until a human diffed it (repaired in `1037101`). This
scanner is the cheap guard that turns such a silent whole-workflow rejection
into a visible CI failure.

What it checks, per workflow file:
  1. **It parses** under `tooling/galaxy/miniyaml.py` (the repo's stdlib YAML
     subset parser — no PyYAML dependency).
  2. **The GitHub structure is intact**: a top-level mapping; `jobs` a
     non-empty mapping; each job a mapping; a job with `steps` has `steps` as a
     *list* whose elements are *mappings*, and every step carries exactly one of
     `uses` / `run` (GitHub's own requirement).
  3. **The #101 boundary-join signature is absent**: a step-boundary token
     (`- name:`, `- uses:`, `- run:`, …) that does NOT begin its line — i.e.
     something swallowed it into the preceding scalar, which is exactly how the
     corrupted `ci.yml` looked.

Usage:
    python3 tooling/gates/workflow_scan.py [root]

Exit codes: 0 clean, 1 violations, 2 usage/read error.
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO / "tooling" / "galaxy"))

from miniyaml import MiniYamlError, loads  # noqa: E402

STEP_KEYS = (
    "id", "if", "name", "uses", "run", "working-directory", "shell", "with",
    "env", "continue-on-error", "timeout-minutes",
)
# A step-boundary token at the start of a line (allowing indentation) is normal;
# the same token with non-whitespace *before* it on the line is the join
# signature (the check below looks at what precedes the match).
BOUNDARY_TOKEN = r"-\s+(?:name|uses|run|with|id|if|shell|env|working-directory)\s*:"
BOUNDARY_RE = re.compile(BOUNDARY_TOKEN)


def _shell_syntax_violations(text: str, label: str) -> list[str]:
    """Check every `run:` block parses as shell (`bash -n`).

    Why: a corrupted line lost its `#` comment prefix in
    `.github/workflows/review-issue.yml` (the #101 signature), which made the
    `respond` job's `run:` block a shell syntax error — the job failed on every
    issue comment until it was found in a CI log (#115). YAML and structure
    checks pass on that file; only shell parsing catches it.
    """
    out: list[str] = []
    try:
        doc = loads(text)
    except MiniYamlError:
        return out
    if not isinstance(doc, dict):
        return out
    jobs = doc.get("jobs") or {}
    if not isinstance(jobs, dict):
        return out
    for jname, job in jobs.items():
        if not isinstance(job, dict):
            continue
        for idx, step in enumerate(job.get("steps") or []):
            if not isinstance(step, dict):
                continue
            run = step.get("run")
            if not isinstance(run, str):
                continue
            shell = step.get("shell", "bash")
            interp = {"bash": "bash", "sh": "sh", "python": "python3"}.get(shell)
            if interp is None:
                continue  # custom shell; cannot check portably
            try:
                r = subprocess.run([interp, "-n"], input=run,
                                   capture_output=True, text=True, timeout=20)
            except (OSError, subprocess.SubprocessError) as e:
                out.append(f"{label}: job '{jname}' step {idx}: could not check "
                           f"shell syntax ({e})")
                continue
            if r.returncode != 0:
                err = (r.stderr or "").strip().splitlines()
                detail = err[-1] if err else "syntax error"
                out.append(
                    f"{label}: job '{jname}' step {idx} ('{step.get('name','')}') "
                    f"run: block is not valid {shell}: {detail}"
                )
    return out


def _violations_for_text(text: str, label: str) -> list[str]:
    out: list[str] = []

    for i, line in enumerate(text.splitlines(), start=1):
        m = BOUNDARY_RE.search(line)
        if m and line[: m.start()].strip():
            out.append(
                f"{label}:{i}: step boundary '{m.group(0).strip()}' is not at the "
                f"start of its line — a step was likely swallowed into the "
                f"preceding scalar (the #101 corruption signature)"
            )

    try:
        doc = loads(text)
    except MiniYamlError as e:
        out.append(f"{label}: does not parse as YAML: {e}")
        return out

    if not isinstance(doc, dict):
        out.append(f"{label}: top level is not a mapping")
        return out

    jobs = doc.get("jobs")
    if not isinstance(jobs, dict) or not jobs:
        out.append(f"{label}: no non-empty 'jobs' mapping")
        return out

    for job_name, job in jobs.items():
        if not isinstance(job, dict):
            out.append(f"{label}: job '{job_name}' is not a mapping")
            continue
        if "steps" not in job:
            continue
        steps = job["steps"]
        if not isinstance(steps, list):
            out.append(
                f"{label}: job '{job_name}' has 'steps' that is not a list "
                f"(got {type(steps).__name__}) — a swallowed boundary can cause this"
            )
            continue
        if not steps:
            out.append(f"{label}: job '{job_name}' has an empty 'steps' list")
        for idx, step in enumerate(steps):
            if not isinstance(step, dict):
                out.append(
                    f"{label}: job '{job_name}' step {idx} is not a mapping "
                    f"(got {type(step).__name__})"
                )
                continue
            has_uses = "uses" in step
            has_run = "run" in step
            if has_uses == has_run:
                out.append(
                    f"{label}: job '{job_name}' step {idx} must have exactly one "
                    f"of 'uses'/'run' (has uses={has_uses}, run={has_run})"
                )
            unknown = [k for k in step if k not in STEP_KEYS]
            if unknown:
                out.append(
                    f"{label}: job '{job_name}' step {idx} has unknown key(s) "
                    f"{unknown} — a swallowed boundary often lands here"
                )
    out.extend(_shell_syntax_violations(text, label))
    return out


def scan(root: Path) -> list[str]:
    wf_dir = root / ".github" / "workflows"
    if not wf_dir.is_dir():
        return []
    findings: list[str] = []
    files = sorted(list(wf_dir.glob("*.yml")) + list(wf_dir.glob("*.yaml")))
    for f in files:
        label = f.relative_to(root).as_posix()
        findings.extend(_violations_for_text(f.read_text(encoding="utf-8"), label))
    return findings


def main(argv: list[str]) -> int:
    root = Path(argv[1]).resolve() if len(argv) > 1 else REPO
    if not root.is_dir():
        print(f"workflow_scan: not a directory: {root}", file=sys.stderr)
        return 2
    findings = scan(root)
    if findings:
        print(f"Gate: workflow integrity — {len(findings)} violation(s):")
        for f in findings:
            print(f"  [VIOLATION] {f}")
        return 1
    wf_dir = root / ".github" / "workflows"
    n = len(list(wf_dir.glob("*.yml")) + list(wf_dir.glob("*.yaml"))) if wf_dir.is_dir() else 0
    print(f"Gate: workflow integrity clean: {n} workflow file(s) parse and are well-formed.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
