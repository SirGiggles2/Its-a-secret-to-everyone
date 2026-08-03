"""evidence.py — parse and validate evidence blocks (spec §4, §4.1, §8.1).

A cell is GREEN only when every rule here passes. There is no code path
that returns GREEN from anything other than a fully verified block.
"""
from __future__ import annotations

import re
from pathlib import Path

import yaml

FENCE = re.compile(r"^```yaml evidence\s*$(.*?)^```\s*$", re.M | re.S)


class MalformedEvidence(Exception):
    """An audit file could not be parsed. Never downgraded to a verdict."""


def parse_blocks(path: Path) -> list[dict]:
    """Return every evidence mapping in `path`, in document order."""
    text = path.read_text(encoding="utf-8")
    out: list[dict] = []
    for match in FENCE.finditer(text):
        try:
            parsed = yaml.safe_load(match.group(1))
        except yaml.YAMLError as exc:
            raise MalformedEvidence(f"{path}: {exc}") from exc
        if parsed is None:
            continue
        if not isinstance(parsed, list):
            raise MalformedEvidence(f"{path}: evidence fence must be a YAML list")
        for item in parsed:
            if not isinstance(item, dict):
                raise MalformedEvidence(f"{path}: evidence entry must be a mapping")
            out.append(item)
    return out
