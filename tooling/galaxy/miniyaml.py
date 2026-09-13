#!/usr/bin/env python3
"""Deterministic stdlib-only YAML subset parser for PleaNP tooling.

The repo convention is pure-stdlib tooling (no PyYAML in the sandbox). This
module parses the subset of YAML used by PleaNP's repo manifests
(``formalization.yaml``): block mappings, nested mappings by indentation,
block sequences (``- item`` / ``- key: value`` with continuation keys), block
scalars (``|``/``|-`` literal, ``>``/``>-`` folded), comments, and quoted
scalars.

Two real-file quirks are handled explicitly (found in ``formalization.yaml``):
* a sequence dash at the *same* indent as its owning key (e.g.
  ``main_results:`` followed by ``- description:`` at the same column), and
* continuation keys after a block-scalar field (e.g. ``description: >-``
  followed by ``declaration:`` at a deeper indent).

Anything outside this subset raises :exc:`MiniYamlError` rather than guessing.
"""
from __future__ import annotations

import re
from typing import Any


class MiniYamlError(ValueError):
    """Raised when a construct outside the supported YAML subset is seen."""


_BLOCK_SCALARS = {"|", "|-", ">", ">-"}


def loads(text: str) -> dict[str, Any]:
    """Parse ``text`` into a nested dict (keys str; values dict/list/scalar)."""
    return _Parser(text.splitlines()).parse()


class _Parser:
    def __init__(self, raw_lines) -> None:
        self.lines = [ln.rstrip("\r\n") for ln in raw_lines]

    def parse(self) -> dict:
        root: dict = {}
        self._parse_block(root, -1, 0)
        return root

    # ------------------------------------------------------------------ #
    # Block mapping — every line is dispatched here or to a sequence.
    # ------------------------------------------------------------------ #
    def _parse_block(self, container: dict, min_indent: int, start: int) -> int:
        """Fill ``container`` from lines[start:]; stop on dedent <= min_indent."""
        i = start
        n = len(self.lines)
        while i < n:
            line = self.lines[i].rstrip()
            if not line.strip() or line.lstrip().startswith("#"):
                i += 1
                continue
            indent = _indent(line)
            if indent <= min_indent:
                return i
            stripped = line.lstrip()
            if stripped.startswith("- ") or stripped == "-":
                # A dash directly in a mapping body is not valid for our
                # subset unless it belongs to a key (handled in
                # _consume_field); treat it as an error to stay honest.
                raise MiniYamlError(
                    f"sequence dash not attached to a key: {line!r}")
            key, rest = _split_key(stripped)
            i += 1
            i = self._consume_field(container, key, rest, indent, i)
        return n

    # ------------------------------------------------------------------ #
    # Block sequence
    # ------------------------------------------------------------------ #
    def _parse_seq(self, target: list, indent: int, start: int) -> int:
        """Parse a block sequence at column ``indent`` into ``target`` list."""
        items, i = self._parse_seq_items(indent, start)
        target.extend(items)
        return i

    def _parse_seq_items(self, indent: int, start: int):
        """Return (items, next_index) for a block sequence at column ``indent``."""
        items: list = []
        i = start
        n = len(self.lines)
        while i < n:
            line = self.lines[i].rstrip()
            if not line.strip() or line.lstrip().startswith("#"):
                i += 1
                continue
            if _indent(line) != indent:
                break
            stripped = line.lstrip()
            if not (stripped.startswith("- ") or stripped == "-"):
                break
            raw = stripped[1:].strip()
            i += 1
            if raw == "":
                # Pure mapping item — keys are the deeper following lines.
                child_indent = self._next_content_indent(i)
                if child_indent is None or child_indent <= indent:
                    items.append(None)
                    continue
                child: dict = {}
                items.append(child)
                i = self._parse_block(child, indent, i)
                continue
            if ":" in raw and not _is_url(raw):
                child: dict = {}
                items.append(child)
                key, rest = _split_key(raw)
                i = self._consume_field(child, key, rest, indent, i)
                ci = self._next_content_indent(i)
                if ci is not None and ci > indent:
                    # Continuation keys belong to this seq item.
                    i = self._parse_block(child, indent, i)
                # Else: leave i pointing at the next line (sibling key or
                # next dash); the outer loop re-checks it.
                continue
            items.append(scalar(raw))
        return items, i

    # ------------------------------------------------------------------ #
    # Field consumption — one mapping field (possibly spanning block scalar).
    # ------------------------------------------------------------------ #
    def _consume_field(self, container: dict, key: str, rest, parent_indent: int,
                       i: int) -> int:
        """Consume the value of ``key`` starting at line ``i``; return next index.

        Handles: inline scalar, ``>-``/``|`` block scalar (content on the
        following deeper lines), nested child mapping, nested sequence (dash
        at same-or-deeper indent), and value-less key (``None``).
        """
        if rest is None:
            nxt = self._next_content(i)
            if nxt is None:
                container[key] = None
                return i
            nxt_i, nxt_ind = nxt
            # A value-less key whose following line is a sequence dash — both
            # at deeper indent (standard YAML) and at the same indent (a quirk
            # in formalization.yaml's main_results/automation/alignment blocks).
            if self.lines[nxt_i].lstrip().startswith("-"):
                owner: list = []
                container[key] = owner
                i = self._parse_seq(owner, nxt_ind, nxt_i)
                # consume_field already consumed lines up to nxt_i; if the
                # sequence ended before the actual next line, skip blanks.
                return i
            if nxt_ind <= parent_indent:
                container[key] = None
                return i
            if nxt_i == i and self._is_block_scalar_marker(nxt_i, nxt_ind):
                content_indent = self._next_content_indent(i + 1)
                if content_indent is None:
                    container[key] = None
                    return i
                value, next_i = self._read_block_scalar(nxt_i, content_indent)
                container[key] = value
                return next_i
            child: dict = {}
            container[key] = child
            return self._parse_block(child, parent_indent, i)
        if rest in _BLOCK_SCALARS:
            # Inline block scalar: the marker is the line we just consumed
            # (i - 1); content follows at a deeper indent.
            child_indent = self._next_content_indent(i)
            if child_indent is None:
                container[key] = None
                return i
            value, next_i = self._read_block_scalar(i - 1, child_indent)
            container[key] = value
            return next_i
        container[key] = scalar(rest)
        return i

    # ------------------------------------------------------------------ #
    # Block scalars
    # ------------------------------------------------------------------ #
    def _is_block_scalar_marker(self, i: int, indent: int) -> bool:
        return (i < len(self.lines)
                and _indent(self.lines[i]) == indent
                and self.lines[i].strip() in _BLOCK_SCALARS)

    def _read_block_scalar(self, marker_i: int, content_indent: int):
        """Return (value, next_index). Content lines live at content_indent."""
        marker_token = self.lines[marker_i].strip().rsplit(":", 1)[-1].strip()
        folded = marker_token.startswith(">")
        parts: list = []
        i = marker_i + 1
        n = len(self.lines)
        while i < n:
            ln = self.lines[i].rstrip()
            if not ln.strip():
                parts.append("")
                i += 1
                continue
            ind = _indent(ln)
            if ind < content_indent:
                break
            parts.append(ln[content_indent:] if len(ln) >= content_indent else "")
            i += 1
        if folded:
            text = " ".join(p.strip() for p in parts if p.strip())
        else:
            text = "\n".join(p.rstrip() for p in parts)
        return text.strip(), i

    # ------------------------------------------------------------------ #
    # Lookahead helpers
    # ------------------------------------------------------------------ #
    def _next_content(self, i: int):
        """Return (index, indent) of the next non-blank, non-comment line."""
        while i < len(self.lines):
            ln = self.lines[i]
            if not ln.strip() or ln.lstrip().startswith("#"):
                i += 1
                continue
            return i, _indent(ln)
        return None

    def _next_content_indent(self, i: int):
        nxt = self._next_content(i)
        return nxt[1] if nxt else None


# ---------------------------------------------------------------------------
# Standalone helpers
# ---------------------------------------------------------------------------
def _indent(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def _split_key(line: str):
    """Return (key, rest) for a mapping line; rest is None when valueless."""
    m = re.match(r"^([^:#]+):(?:\s+(.*))?$", line)
    if not m:
        raise MiniYamlError(f"unsupported YAML construct: {line!r}")
    key = m.group(1).strip().strip("'\"")
    rest = m.group(2)
    if rest is not None:
        rest = _strip_inline_comment(rest).strip()
        if rest == "":
            rest = None
    return key, rest


def _strip_inline_comment(s: str) -> str:
    idx = s.find(" #")
    return s[:idx].strip() if idx >= 0 else s


def _is_url(s: str) -> bool:
    return s.startswith(("http://", "https://"))


def scalar(val: str):
    v = val.strip()
    if len(v) >= 2 and v[0] == '"' and v[-1] == '"':
        return v[1:-1]
    if len(v) >= 2 and v[0] == "'" and v[-1] == "'":
        return v[1:-1]
    if v in ("true", "True", "TRUE"):
        return True
    if v in ("false", "False", "FALSE"):
        return False
    if v in ("null", "None", "~"):
        return None
    if re.fullmatch(r"-?\d+", v):
        return int(v)
    if re.fullmatch(r"-?\d+\.\d+", v):
        return float(v)
    return v



