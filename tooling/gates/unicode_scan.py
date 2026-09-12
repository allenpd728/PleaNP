#!/usr/bin/env python3
"""Gate 8 (Tier 1) -- Unicode-hygiene scanner for PleaNP source.

Flags stray, non-valid characters in tracked source files: characters that are
not valid parts of Lean 4, the metaprogramming layer, or the project's prose
conventions, but that routinely arrive as LLM/CJK-IME authoring artifacts.

Catches the 2026-09-12 audit class (see docs/FAILURE_AUDIT.md): fullwidth
ASCII swaps (the U+FF01..FF5E and U+FF61..FFEF blocks), CJK punctuation
(U+3000..U+303F), invisible format characters (zero-width space, LRM/RLM,
bidi controls, soft hyphen), a stray Devanagari danda (U+0964), and combining
diacritics inserted as standalone characters (e.g. a heading that is a bare
U+0304 before a digit) or glued to the wrong base (e.g. a combining char
after a space). None of these is ever a valid part of Lean 4 or of this
project's English prose.

What is ALLOWED -- the repo's genuine non-ASCII:
- math/Lean glyphs: Greek, arrows, operators (∀ ∃ ∈ ⊆ ∧ ∨ ¬ ≠), ℕ ∅,
  ▸ (Lean cast token), ·, §, superscripts/subscripts, ⟨⟩, box drawing
- precomposed Latin letters in names (ö, ř, è, Ã for A-tilde)
- B-tilde (B + U+0303 combining tilde) in the Algebrization spec -- no
  precomposed form exists, so the combining tilde is the ONLY correct spelling
- emoji with VS-16 (⚠️) in CLI output and tests; decorative tiles (🀰)
- LRM U+200E inside the two bidi-sensitive files (LOG.md, LESSONS) -- reported
  as SOFT (never exit 1) until a careful editor removes them; elsewhere LRM is
  a violation.
- `--allow` / `--allow-file` provide an audited escape hatch: a future file
  with a legitimately-required flagged character is documented there, not
  smuggled.

The scanner is Tier 1: pure text, no Lean toolchain, deliberately
conservative. It enforces authoring hygiene so stray characters never re-enter
`dev` (AGENTS.md Git workflow); it proves nothing about the Lean kernel
(that is Gate 4/6 Tier 2). Complements hygiene_scan (Gate 6), vacuity_scan
(Gate 5), binder_usage_scan (Gate 7).

Exit codes: 0 clean, 1 violations found, 2 usage error.
"""
from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path

# ---------------------------------------------------------------------------
# Banned character classes. Banned classes are checked FIRST and always win
# over the legal-block ranges: for a char that sits in both (e.g. 0x2460,
# which math fonts love but the audit flagged), the ban decides.
# ---------------------------------------------------------------------------

# Fullwidth ASCII swaps U+FF01..FF5E and halfwidth forms U+FF61..FFEF.
FULLWIDTH_RANGES = (range(0xFF01, 0xFF5F), range(0xFF61, 0xFFF0))
# CJK punctuation U+3000..U+303F, CJK radicals U+2E80..U+2EFF, Kangxi
# radicals U+2F00..U+2FDF.
CJK_RANGES = (range(0x3000, 0x3040), range(0x2E80, 0x2F00), range(0x2F00, 0x2FE0))
# CJK ideographs + kana + hangul (keep new CJK text out of the tree).
CJK_TEXT_RANGES = (
    range(0x3040, 0x3100), range(0x3200, 0x3300), range(0x3400, 0x4DC0),
    range(0x4E00, 0xA000), range(0xF900, 0xFB00), range(0x20000, 0x2FFFF),
    range(0x1100, 0x1200), range(0xAC00, 0xD7B0),
)
# Invisible / format characters.
INVIS_ZW = {"\u200b", "\u200c", "\u200d"}
INVIS_BIDI = {"\u200e", "\u200f", "\u202a", "\u202b", "\u202c", "\u202d", "\u202e"}
INVIS_OPS = {"\u2060", "\u2061", "\u2062", "\u2063", "\u2064"}
INVIS_MISC = {"\ufeff", "\u00ad", "\u180e", "\u2028", "\u2029"}
# Combining diacritics U+0300..U+036F -- contextual: legal after a Letter
# (B + U+0303 = B-tilde), flagged after a space/digit/punct (the artifact
# position, e.g. a heading starting with a bare U+0304 or a combining char
# glued to a space).
COMBINING_RANGES = (range(0x0300, 0x0370),)
# Devanagari punctuation (U+0964 danda).
DEVANAGARI_PUNCT = {"\u0964", "\u0965"}
# Circled/enclosed alphanumerics U+2460..U+24FF (enclosed digits, U+2461
# etc. -- authoring artifacts substituting for plain numerals).
CIRCLED_RANGES = (range(0x2460, 0x2500),)
# Variation selectors U+FE00..U+FE0F (VS-16 legal only after an emoji base).
VS_RANGES = (range(0xFE00, 0xFE10),)

# ---------------------------------------------------------------------------
# Legal Unicode blocks (prose/math/Lean). Ranges are half-open.
# ---------------------------------------------------------------------------

LEGAL_RANGES = (
    range(0x00A1, 0x00AC),    # Latin-1 supplement (¡ ¢ £ … « ¬)
    range(0x00AC, 0x00AD),    # NOT SIGN
    range(0x00AE, 0x0100),    # Latin-1 supplement rest (®, °, ±, §, ×, ÷, accented)
    range(0x0100, 0x0180),    # Latin Extended-A (č ř …)
    range(0x02B0, 0x0300),    # Spacing modifier letters (ˇ caron …)
    range(0x0370, 0x03D0),    # Greek (Γ Σ Ω α β …)
    range(0x2012, 0x2016),    # en/em dash, horizontal bar
    range(0x2018, 0x2020),    # curly quotes, † ‡
    range(0x2026, 0x2027),    # ellipsis
    range(0x2032, 0x2035),    # prime marks (′ ″ ‴)
    range(0x2039, 0x203B),    # guillemets (‹ ›)
    range(0x2070, 0x209D),    # super/subscripts (⁰ ₀ ⁿ ₙ …)
    range(0x2100, 0x2150),    # letterlike (ℕ ℂ ℍ ℙ ℝ ℤ ℓ …)
    range(0x2190, 0x21FF),    # arrows (← → ↔ ↦ ⇐ ⇒ ⇔ …)
    range(0x2200, 0x2300),    # math operators (∀ ∃ ∈ ⊆ ∧ ∨ ¬ ≠ …)
    range(0x2500, 0x2580),    # box drawing
    range(0x25A0, 0x2600),    # geometric shapes (▸ ► ● …)
    range(0x2600, 0x2700),    # misc symbols (⚠ ⛔ ☀ …)
    range(0x2700, 0x27C0),    # dingbats (✅ ✈ …)
    range(0x27C0, 0x2B00),    # misc math A/B + supplemental arrows (⟨⟩ ⟶ ⟹) + stars
    range(0x2B00, 0x2C00),    # misc symbols/arrows (⭐ …)
    range(0x1D400, 0x1D800),  # mathematical alphanumerics (𝒞 𝒫 …)
    range(0x1F000, 0x1FB00),  # symbols/pictographs (🀰 …)
)

# LRM (U+200E) legality: reported but never fails build inside these files
# (the paired en-dash/quote context there makes removal a careful edit; the
# 2026-09-12 cleanup deliberately leaves them as SOFT so CI stays green).
LRM_LEGAL_FILES = {
    "docs/LEAN_FORMALIZATION_LESSONS_2026-09-10.md",
    "docs/decisions/LOG.md",
}

DESC = {
    "fullwidth": "fullwidth/halfwidth form",
    "cjk-punct": "CJK punctuation (incl. radicals)",
    "cjk-text": "CJK ideograph/kana/hangul",
    "invisible-zw": "zero-width (ZWSP/ZWNJ/ZWJ)",
    "invisible-bidi": "bidi / format direction mark",
    "invisible-ops": "invisible operator / format char",
    "invisible-misc": "format char (BOM/soft-hyphen/line-or-para-sep)",
    "combining": "combining diacritic (flagged unless after a letter)",
    "devanagari": "Devanagari punctuation",
    "circled": "circled / enclosed alphanumeric",
    "vs": "variation selector (VS-16 legal only after an emoji base)",
}


@dataclass
class Finding:
    file: Path
    line_no: int
    col: int
    kind: str
    char: str
    desc: str


def _char_kind(ch: str) -> str | None:
    cp = ord(ch)
    for r in FULLWIDTH_RANGES:
        if cp in r:
            return "fullwidth"
    for r in CJK_RANGES:
        if cp in r:
            return "cjk-punct"
    for r in CJK_TEXT_RANGES:
        if cp in r:
            return "cjk-text"
    if ch in INVIS_ZW:
        return "invisible-zw"
    if ch in INVIS_BIDI:
        return "invisible-bidi"
    if ch in INVIS_OPS:
        return "invisible-ops"
    if ch in INVIS_MISC:
        return "invisible-misc"
    for r in COMBINING_RANGES:
        if cp in r:
            return "combining"
    if ch in DEVANAGARI_PUNCT:
        return "devanagari"
    for r in CIRCLED_RANGES:
        if cp in r:
            return "circled"
    for r in VS_RANGES:
        if cp in r:
            return "vs"
    return None


def _legal_block(cp: int) -> bool:
    for r in LEGAL_RANGES:
        if cp in r:
            return True
    return False


def scan_text(text: str, path: Path, allow: set[str] | None = None,
              lrm_legal: bool = False) -> list[Finding]:
    """Scan one file. `allow`: exact flagged chars audited as required.
    `lrm_legal`: report LRM as SOFT for the bidi-sensitive files."""
    allow = allow or set()
    findings: list[Finding] = []
    for i, line in enumerate(text.splitlines(), 1):
        prev = ""
        for j, ch in enumerate(line):
            kind = _char_kind(ch)
            if kind is None:
                prev = ch
                continue
            # Explicit audited allowances win over everything.
            if ch in allow:
                prev = ch
                continue
            # Soft LRM: the two bidi-sensitive files (report, exit 0).
            if kind == "invisible-bidi" and ch == "\u200e" and lrm_legal:
                findings.append(Finding(path, i, j, kind, ch,
                                        "LRM (soft: bidi-sensitive file)"))
                prev = ch
                continue
            # Contextual legal: combining diacritic after a Letter = B̃ / Ã.
            if kind == "combining" and prev.isalpha():
                prev = ch
                continue
            # Contextual legal: VS-16 after an allowed emoji base.
            if kind == "vs" and prev in {"\u26a0", "\u2705", "\u26d4", "\u2b50"}:
                prev = ch
                continue
            # A char in a legal block passes unless it is also in a banned
            # class (banned classes always win, so this stays conservative).
            if _legal_block(ord(ch)):
                prev = ch
                continue
            findings.append(Finding(path, i, j, kind, ch, DESC[kind]))
            prev = ch
    return findings


def scan(paths: list[Path], allow: set[str] | None = None) -> list[Finding]:
    files: list[Path] = []
    for p in paths:
        if p.is_dir():
            files.extend(sorted(p.rglob("*")))
        else:
            files.append(p)
    wanted_suffixes = {".lean", ".py", ".md", ".yaml", ".yml", ".json", ".toml"}
    files = [f for f in files if f.is_file() and f.suffix in wanted_suffixes]
    files = sorted(set(files))

    all_findings: list[Finding] = []
    for f in files:
        try:
            raw = f.read_bytes()
        except Exception as e:  # unreadable -- report, don't crash
            print(f"warning: could not read {f}: {e}", file=sys.stderr)
            continue
        text = raw.decode("utf-8", errors="replace")
        if "\ufffd" in text:
            print(f"warning: {f} contains invalid UTF-8 (replacement chars present)",
                  file=sys.stderr)
        lrm_legal = str(f) in LRM_LEGAL_FILES
        all_findings.extend(scan_text(text, f, allow=allow, lrm_legal=lrm_legal))
    return all_findings


def main() -> int:
    ap = argparse.ArgumentParser(description="Gate 8 (Tier 1) Unicode-hygiene scanner")
    ap.add_argument("path", nargs="+", type=Path, help="file or dir to scan")
    ap.add_argument("--allow", default="",
                    help="comma-separated exact characters to allow (audited)")
    ap.add_argument("--allow-file", type=Path,
                    help="file with one allowed character per line (# comments ok)")
    args = ap.parse_args()

    allow: set[str] = set(args.allow)
    if args.allow_file and args.allow_file.exists():
        for raw in args.allow_file.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if line and not line.startswith("#"):
                allow.add(line[0])

    findings = scan(args.path, allow=allow)

    if findings:
        print(f"Gate 8 (Tier 1) findings across {len(set(f.file for f in findings))} file(s):")
        for f in findings:
            soft = f.kind == "invisible-bidi" and str(f.file) in LRM_LEGAL_FILES
            tag = "SOFT" if soft else "VIOLATION"
            print(f"  [{tag}] {f.kind:15} {f.file}:{f.line_no}:{f.col}  "
                  f"U+{ord(f.char):04X}  {f.desc}  | {f.char!r}")
        soft = [f for f in findings
                if f.kind == "invisible-bidi" and str(f.file) in LRM_LEGAL_FILES]
        viol = [f for f in findings if f not in soft]
        print()
        print(f"  {len(viol)} violation(s), {len(soft)} soft (bidi-sensitive-file LRM)")
        return 1 if viol else 0
    print(f"Gate 8 (Tier 1) clean: no stray/non-valid Unicode chars in "
          f"{len(args.path)} path(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())