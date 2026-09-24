from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools" / "audit" / "completion"))

import evidence
import signing


def sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def make_repo(tmp_path: Path) -> tuple[Path, bytes, dict]:
    """A minimal valid repo: one artifact, one input, a signed block."""
    (tmp_path / "docs").mkdir(exist_ok=True)
    art = tmp_path / "docs" / "status.md"
    art.write_text("Total 171/171 PASS\n", encoding="utf-8")
    src = tmp_path / "rooms.c"
    src.write_text("const int x = 1;\n", encoding="utf-8")

    key = signing.load_or_create_key(tmp_path / ".k")
    block = {
        "system": "dungeons",
        "axis": "DATA",
        "verdict": "GREEN",
        "artifact": "docs/status.md",
        "artifact_sha256": sha(art),
        "command": "python run.py",
        "verdict_line": "Total 171/171 PASS",
        "manifest_emitted_by": "tools/parity/run.py",
        "inputs": [{"path": "rooms.c", "sha256": sha(src)}],
    }
    block["run_signature"] = signing.sign(key, block)
    return tmp_path, key, block


SCHEMA = json.loads(
    (ROOT / "tools" / "audit" / "completion" / "schema.json").read_text(encoding="utf-8")
)


# ── Rules 1-2: artifact existence and integrity ──────────────────────────

def test_valid_block_is_green(tmp_path: Path) -> None:
    root, key, block = make_repo(tmp_path)
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "GREEN", result.reasons


def test_missing_artifact_is_red(tmp_path: Path) -> None:
    root, key, block = make_repo(tmp_path)
    (root / "docs" / "status.md").unlink()
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("artifact missing" in r for r in result.reasons)


def test_artifact_hash_drift_is_red(tmp_path: Path) -> None:
    root, key, block = make_repo(tmp_path)
    (root / "docs" / "status.md").write_text("Total 170/171 PASS\n", encoding="utf-8")
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("artifact hash drift" in r for r in result.reasons)


# ── Rule 3: inputs must match and be tool-emitted ────────────────────────

def test_input_hash_drift_is_red(tmp_path: Path) -> None:
    root, key, block = make_repo(tmp_path)
    (root / "rooms.c").write_text("const int x = 2;\n", encoding="utf-8")
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("input hash drift" in r for r in result.reasons)
    assert "rooms.c" in result.drift


def test_missing_manifest_emitter_is_red(tmp_path: Path) -> None:
    """Hand-authored inputs[] are not trusted (finding A)."""
    root, key, block = make_repo(tmp_path)
    del block["manifest_emitted_by"]
    block["run_signature"] = signing.sign(key, block)
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("manifest_emitted_by" in r for r in result.reasons)


def test_empty_inputs_is_red(tmp_path: Path) -> None:
    root, key, block = make_repo(tmp_path)
    block["inputs"] = []
    block["run_signature"] = signing.sign(key, block)
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("inputs" in r for r in result.reasons)


# ── Rules 4-5: verbatim verdict line, verified signature ─────────────────

def test_verdict_line_absent_from_artifact_is_red(tmp_path: Path) -> None:
    root, key, block = make_repo(tmp_path)
    block["verdict_line"] = "Total 999/999 PASS"
    block["run_signature"] = signing.sign(key, block)
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("verdict_line not found" in r for r in result.reasons)


def test_missing_signature_is_red(tmp_path: Path) -> None:
    """A hand-typed block cannot mint GREEN (finding C)."""
    root, key, block = make_repo(tmp_path)
    del block["run_signature"]
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("run_signature" in r for r in result.reasons)


def test_edited_input_invalidates_signature(tmp_path: Path) -> None:
    root, key, block = make_repo(tmp_path)
    block["inputs"].append({"path": "rooms.c", "sha256": "00" * 32})
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("run_signature" in r for r in result.reasons)


def test_command_absent_is_red(tmp_path: Path) -> None:
    root, key, block = make_repo(tmp_path)
    del block["command"]
    block["run_signature"] = signing.sign(key, block)
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("command" in r for r in result.reasons)
