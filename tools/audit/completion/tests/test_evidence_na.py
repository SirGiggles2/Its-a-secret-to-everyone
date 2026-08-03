from __future__ import annotations

import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools" / "audit" / "completion"))

import evidence
import signing

SCHEMA = json.loads(
    (ROOT / "tools" / "audit" / "completion" / "schema.json").read_text(encoding="utf-8")
)


def test_allowlisted_na_is_accepted(tmp_path: Path) -> None:
    key = signing.load_or_create_key(tmp_path / ".k")
    block = {
        "system": "modes",
        "axis": "DATA",
        "verdict": "N/A",
        "reason": "Game-mode dispatch owns no assets.",
    }
    assert evidence.evaluate(block, tmp_path, key, SCHEMA).verdict == "N/A"


def test_na_without_allowlist_entry_is_red(tmp_path: Path) -> None:
    """Prose alone cannot exempt a cell (finding D)."""
    key = signing.load_or_create_key(tmp_path / ".k")
    block = {
        "system": "dungeons",
        "axis": "DATA",
        "verdict": "N/A",
        "reason": "we will get to it later",
    }
    result = evidence.evaluate(block, tmp_path, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("na_allowlist" in r for r in result.reasons)


def test_na_without_reason_is_red(tmp_path: Path) -> None:
    key = signing.load_or_create_key(tmp_path / ".k")
    block = {"system": "modes", "axis": "DATA", "verdict": "N/A"}
    result = evidence.evaluate(block, tmp_path, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("reason" in r for r in result.reasons)


def test_behavior_without_tolerance_is_red(tmp_path: Path) -> None:
    from test_evidence_rules import make_repo

    root, key, block = make_repo(tmp_path)
    block["axis"] = "BEHAVIOR"
    block["run_signature"] = signing.sign(key, block)
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("tolerance" in r for r in result.reasons)


def test_behavior_with_tolerance_is_green(tmp_path: Path) -> None:
    from test_evidence_rules import make_repo

    root, key, block = make_repo(tmp_path)
    block["axis"] = "BEHAVIOR"
    block["tolerance"] = "X/Y differ on moving bosses: RNG frame phase, not divergence."
    block["run_signature"] = signing.sign(key, block)
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "GREEN", result.reasons
