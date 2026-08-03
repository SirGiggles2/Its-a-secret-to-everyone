"""collect.py — build the completion tracker from on-disk evidence.

Status is a pure function of the filesystem. Absence of evidence is RED.
There is NO positional default — the defect that made the prime-directive
tracker report 18/18 phases complete against a build with no save system,
no file select, and a 0/18 dungeon harness.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import evidence
import model
import signing

SYSTEMS_DIR = Path("docs") / "audit" / "systems"
TRACKER = Path("docs") / "audit" / "completion_tracker.json"

# The schema ships with the tool, not with the tree being audited.
TOOL_ROOT = Path(__file__).resolve().parents[3]


def load_schema() -> dict:
    path = TOOL_ROOT / "tools" / "audit" / "completion" / "schema.json"
    return json.loads(path.read_text(encoding="utf-8"))


def build(root: Path) -> dict:
    """Return the tracker for `root`. Never raises on a RED cell — only on
    input the collector cannot interpret at all (malformed / duplicate)."""
    root = Path(root)
    schema = load_schema()
    key = signing.load_or_create_key(
        root / "tools" / "audit" / "completion" / ".evidence_key"
    )

    blocks: dict[tuple[str, str], dict] = {}
    for system in model.SYSTEMS:
        path = root / SYSTEMS_DIR / f"{system}.md"
        if not path.is_file():
            continue
        for block in evidence.parse_blocks(path):
            cell = (str(block.get("system")), str(block.get("axis")))
            if cell in blocks:
                raise evidence.MalformedEvidence(
                    f"{path}: duplicate claim for {cell} — a (system, axis) pair "
                    "may be claimed exactly once. Note that one artifact serving "
                    "many cells is normal and is NOT a duplicate."
                )
            blocks[cell] = block

    cells = []
    for system, axis in model.all_cells():
        block = blocks.get((system, axis))
        if block is None:
            audit_exists = (root / SYSTEMS_DIR / f"{system}.md").is_file()
            reason = (
                "no evidence block for this cell"
                if audit_exists
                else "audit not yet run for this system"
            )
            cells.append(
                {
                    "system": system,
                    "axis": axis,
                    "verdict": "RED",
                    "artifact": None,
                    "reasons": [reason],
                    "drift": [],
                }
            )
            continue
        result = evidence.evaluate(block, root, key, schema)
        cells.append(
            {
                "system": system,
                "axis": axis,
                "verdict": result.verdict,
                "artifact": block.get("artifact"),
                "reasons": result.reasons,
                "drift": result.drift,
            }
        )
    return {"schema_version": 1, "cells": cells}


def serialize(tracker: dict) -> str:
    """Canonical JSON — sorted, compact, no environment-derived fields."""
    return json.dumps(
        tracker, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Build the completion tracker.")
    parser.add_argument("--root", default=".", help="repository root")
    args = parser.parse_args()
    root = Path(args.root).resolve()
    try:
        tracker = build(root)
    except evidence.MalformedEvidence as exc:
        print(f"MALFORMED: {exc}", file=sys.stderr)
        return 1
    (root / TRACKER).parent.mkdir(parents=True, exist_ok=True)
    (root / TRACKER).write_text(serialize(tracker), encoding="utf-8")
    red = sum(1 for c in tracker["cells"] if c["verdict"] == "RED")
    print(f"completion tracker: {80 - red}/80 satisfied, {red} RED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
