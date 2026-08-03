from __future__ import annotations

import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools" / "audit" / "completion"))

import model

SCHEMA = ROOT / "tools" / "audit" / "completion" / "schema.json"


def load() -> dict:
    return json.loads(SCHEMA.read_text(encoding="utf-8"))


def test_schema_parses() -> None:
    assert load()["schema_version"] == 1


def test_na_allowlist_exists() -> None:
    assert isinstance(load()["na_allowlist"], list)


def test_na_allowlist_entries_are_valid_cells() -> None:
    for entry in load()["na_allowlist"]:
        assert entry["system"] in model.SYSTEMS
        assert entry["axis"] in model.AXES
        assert entry["reason"].strip()


def test_required_evidence_fields_declared() -> None:
    required = load()["required_evidence_fields"]
    for field in (
        "system", "axis", "verdict", "artifact", "artifact_sha256",
        "command", "verdict_line", "run_signature", "manifest_emitted_by",
        "inputs",
    ):
        assert field in required
