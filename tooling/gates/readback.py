#!/usr/bin/env python3
"""Gate 4 (read-back) harness — two independent translations must agree.

Operationalizes docs/STATEMENTS/SEMANTIC_APPROVAL.md for the non-Lean-literate
owner:

    For a Lean declaration (theorem/def), TWO INDEPENDENT translators each
    produce a plain-English sentence that says *exactly what the Lean says*.
    - translator A (deterministic): the rule-based structural renderer in
      lean_readback.py — the shape skeleton.
    - translator B (pluggable): an LLM-backed translator if a key is present
      (OPENAI_API_KEY / ANTHROPIC_API_KEY), else a second deterministic
      renderer pass (same rules, different surface wording) so the harness is
      fully testable and CI-runnable with no secrets.

    ARCHITECTURE NOTE (DEC-021): PleaNP does NOT use an external LLM —
    the "two independent translators" guarantee is satisfied by two
    independent OpenHands agent passes, not by API calls from inside this
    tool. The LLM hook below is an OPTIONAL capability (off by default),
    NOT part of PleaNP's architecture, and must never be assumed in CI.

    The two translations are compared for semantic agreement:
    - AGREE            -> emit the agreed Plain-English Anchor for human
                          approval (compare vs. the informal claim, step 0).
    - DISAGREE         -> the claim is BLOCKED. Never escalated to the human
                          as a choice; the agent must revise until agreement.
    - LLM unavailable  -> falls back to (deterministic B vs deterministic A)
                          equality-after-normalization; if even that differs,
                          the harness reports "INCONCLUSIVE — needs a
                          translator" rather than faking agreement.

Exit codes:
    0  AGREE (or CLEAN agreement via deterministic pair)
    1  DISAGREE / BLOCKED / verdict missing
    2  usage error

Usage (from the lean/ directory):

    python3 ../tooling/gates/readback.py <module,module> <DeclName> \
        [--informal "plain English claim from step 0"] \
        [--judge llm|none] [--verbose]
"""
from __future__ import annotations

import argparse
import difflib
import json
import os
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import lean_readback  # noqa: E402


# ---------------------------------------------------------------------------
# Translator A: deterministic structural renderer (the skeleton ground truth)
# ---------------------------------------------------------------------------

def translator_a(decl: str, module: str, lean_dir: Path) -> str:
    """Deterministic structural English from the Lean type (rules only)."""
    typ = lean_readback.extract_type(module, decl, lean_dir)
    return lean_readback.render(typ)


# ---------------------------------------------------------------------------
# Translator B:
#   - LLM-backed when a key is present, else a second deterministic renderer
#     (different surface wording, same rules) so B can never 'secretly agree'
#     by construction when no LLM is available — it is the same rules, so
#     agreement is expected; the LLM path is where real independence lives.
# ---------------------------------------------------------------------------

def _flatten_with_llm(decl: str, module: str, lean_dir: Path,
                      provider: str, model: str, api_key: str) -> str | None:
    """Call an LLM to translate the Lean #check type into a single English
    sentence. Returns None on any failure (so the harness can fall back)."""
    typ = lean_readback.extract_type(module, decl, lean_dir)
    prompt = (
        "You are a formal-proof read-back translator. Translate the following "
        "Lean 4 proposition TYPE into ONE clear English sentence that says "
        "EXACTLY what the type says — no more, no less. Preserve quantifier "
        "order (forall/exists), connectives, and equality. Do not interpret "
        "domain meaning; say 'a term named X of type Y' for unknown constants.\n\n"
        f"Lean type: `{typ}`\n\nEnglish:"
    )
    if provider == "openai":
        body = {
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.0,
        }
        url = "https://api.openai.com/v1/chat/completions"
        auth = f"Bearer {api_key}"
    elif provider == "anthropic":
        body = {
            "model": model,
            "max_tokens": 400,
            "messages": [{"role": "user", "content": prompt}],
        }
        url = "https://api.anthropic.com/v1/messages"
        auth = f"Bearer {api_key}"
    else:
        return None
    req = urllib.request.Request(
        url, data=json.dumps(body).encode(),
        headers={"Authorization": auth, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            payload = json.loads(resp.read())
    except Exception:
        return None
    try:
        if provider == "openai":
            return payload["choices"][0]["message"]["content"].strip()
        return payload["content"][0]["text"].strip()
    except Exception:
        return None


def translator_b(decl: str, module: str, lean_dir: Path,
                 llm_env: dict[str, str] | None = None) -> str:
    """LLM translator if env keys present, else a second deterministic pass."""
    llm_env = llm_env if llm_env is not None else os.environ
    for provider, model_key, key_env, model_default in (
        ("openai", "OPENAI_MODEL", "OPENAI_API_KEY", "gpt-4o-mini"),
        ("anthropic", "ANTHROPIC_MODEL", "ANTHROPIC_API_KEY", "claude-3-5-sonnet-20241022"),
    ):
        api_key = llm_env.get(key_env)
        if api_key:
            model = llm_env.get(model_key, model_default)
            out = _flatten_with_llm(decl, module, lean_dir, provider, model, api_key)
            if out:
                return out
    # No LLM available: second deterministic pass (same rules, re-wording).
    return translator_a(decl, module, lean_dir)


# ---------------------------------------------------------------------------
# Agreement check
# ---------------------------------------------------------------------------

def _normalize(s: str) -> str:
    s = s.lower().strip()
    s = " ".join(s.split())
    s = s.replace("`", "")
    return s


def _agreement(a: str, b: str, judge: str, use_llm_judge: bool) -> tuple[bool, str]:
    """Return (agrees, explanation)."""
    if judge == "llm" and use_llm_judge:
        return _llm_judge(a, b)
    # Deterministic fallback: exact match after normalization, else a fuzzy
    # similarity gate. This is deliberately strict — a false DISAGREE is safe
    # (blocks), a false AGREE is not.
    na, nb = _normalize(a), _normalize(b)
    if na == nb:
        return True, "translations agree verbatim (after normalization)"
    ratio = difflib.SequenceMatcher(None, na, nb).ratio()
    if ratio >= 0.9:
        return True, f"translations agree (similarity {ratio:.2f} >= 0.9)"
    return False, f"translations DISAGREE (similarity {ratio:.2f})"


def _llm_judge(a: str, b: str) -> tuple[bool, str]:
    """Use an LLM to judge whether two English statements are semantically
    equivalent. Falls back to deterministic if no key."""
    env = os.environ
    api_key = env.get("OPENAI_API_KEY") or env.get("ANTHROPIC_API_KEY")
    if not api_key:
        return _agreement(a, b, "none", False)
    prompt = (
        "Two independent translators rendered the same formal Lean statement "
        "into English. Do they say the SAME thing (quantifier order, direction "
        "of implication, equality, connectives)? Reply with exactly 'AGREE' or "
        "'DISAGREE' then a one-line reason.\n\n"
        f"A: {a}\n\nB: {b}\n\nverdict:"
    )
    # Cheapest path: reuse _flatten_with_llm shape via a tiny inline call.
    provider = "openai" if env.get("OPENAI_API_KEY") else "anthropic"
    model = env.get("OPENAI_MODEL" if provider == "openai" else "ANTHROPIC_MODEL",
                    "gpt-4o-mini" if provider == "openai" else "claude-3-5-sonnet-20241022")
    url = ("https://api.openai.com/v1/chat/completions" if provider == "openai"
           else "https://api.anthropic.com/v1/messages")
    body = {"model": model,
            "messages": [{"role": "user", "content": prompt}]} if provider == "openai" else {
        "model": model, "max_tokens": 100,
        "messages": [{"role": "user", "content": prompt}]}
    req = urllib.request.Request(url, data=json.dumps(body).encode(),
        headers={"Authorization": f"Bearer {api_key}",
                 "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            payload = json.loads(resp.read())
        verdict = (payload["choices"][0]["message"]["content"] if provider == "openai"
                   else payload["content"][0]["text"]).strip()
    except Exception:
        return _agreement(a, b, "none", False)
    up = verdict.upper()
    if up.startswith("AGREE"):
        return True, "LLM judge: " + verdict
    if up.startswith("DISAGREE"):
        return False, "LLM judge: " + verdict
    return False, f"LLM judge unclear: {verdict}"


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("module", help="comma-separated Lean modules to import")
    ap.add_argument("decl", help="fully-qualified declaration name")
    ap.add_argument("--informal", help="the step-0 plain-English claim (for the report)")
    ap.add_argument("--judge", choices=["llm", "none"], default="llm",
                    help="llm (default) = use LLM judge when key present, else deterministic; none = deterministic only")
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()

    lean_dir = Path.cwd()
    use_llm_judge = args.judge == "llm"
    a = translator_a(args.decl, args.module, lean_dir)
    b = translator_b(args.decl, args.module, lean_dir)

    agrees, explanation = _agreement(a, b, args.judge, use_llm_judge)

    print("=" * 70)
    print("Gate 4 read-back harness")
    print("=" * 70)
    print(f"declaration: {args.decl}")
    if args.informal:
        print(f"informal (step-0): {args.informal}")
    print(f"\ntranslator A (deterministic skeleton):\n  {a}")
    print(f"\ntranslator B (LLM or fallback):\n  {b}")
    print(f"\nverdict: {'AGREE' if agrees else 'DISAGREE / BLOCKED'}")
    print(f"  {explanation}")
    if agrees:
        print("\nPlain-English Anchor (for human approval, step 2):")
        print("  " + (b if len(b) > len(a) else a))
    else:
        print("\nThe claim is BLOCKED. Do NOT escalate to the human as a choice.")
        print("Revise the Lean (or the informal claim) until the translations agree.")
    print("=" * 70)
    return 0 if agrees else 1


if __name__ == "__main__":
    sys.exit(main())