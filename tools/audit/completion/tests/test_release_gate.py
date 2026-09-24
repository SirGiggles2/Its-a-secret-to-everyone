from __future__ import annotations

import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools" / "audit" / "completion"))
sys.path.insert(0, str(ROOT / "tools" / "builder"))

import completion_gate
import model


def seed(tmp_path: Path) -> Path:
    (tmp_path / "docs" / "audit" / "systems").mkdir(parents=True)
    return tmp_path


def test_all_red_refuses(tmp_path: Path) -> None:
    ok, msg = completion_gate.check(seed(tmp_path), overrides={})
    assert ok is False
    assert "80" in msg


def test_stale_green_tracker_on_disk_is_ignored(tmp_path: Path) -> None:
    """The gate re-collects; it never trusts the file on disk."""
    root = seed(tmp_path)
    fake = {
        "schema_version": 1,
        "cells": [
            {
                "system": s, "axis": a, "verdict": "GREEN",
                "artifact": None, "reasons": [], "drift": [],
            }
            for s in model.SYSTEMS
            for a in model.AXES
        ],
    }
    (root / "docs" / "audit" / "completion_tracker.json").write_text(
        json.dumps(fake), encoding="utf-8"
    )
    ok, _ = completion_gate.check(root, overrides={})
    assert ok is False


def test_override_allows_but_records(tmp_path: Path) -> None:
    root = seed(tmp_path)
    overrides = {
        f"{s}/{a}": {"reason": "bootstrap", "approved_by": "jake"}
        for s in model.SYSTEMS
        for a in model.AXES
    }
    ok, msg = completion_gate.check(root, overrides=overrides)
    assert ok is True
    assert "override" in msg.lower()


def test_partial_override_still_refuses(tmp_path: Path) -> None:
    """One override does not unblock the other 79 cells."""
    root = seed(tmp_path)
    ok, msg = completion_gate.check(
        root, overrides={"dungeons/DATA": {"reason": "x", "approved_by": "jake"}}
    )
    assert ok is False
    assert "79" in msg
