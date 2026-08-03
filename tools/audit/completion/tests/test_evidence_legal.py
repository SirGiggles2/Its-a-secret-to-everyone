from __future__ import annotations

import hashlib
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


def build(tmp_path: Path, rel: str, size: int = 32) -> tuple[Path, bytes, dict]:
    target = tmp_path / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    body = "Total 1/1 PASS\n" + ("x" * size)
    target.write_text(body, encoding="utf-8")
    src = tmp_path / "in.c"
    src.write_text("int x;\n", encoding="utf-8")
    key = signing.load_or_create_key(tmp_path / ".k")
    block = {
        "system": "dungeons",
        "axis": "DATA",
        "verdict": "GREEN",
        "artifact": rel,
        "artifact_sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
        "command": "python run.py",
        "verdict_line": "Total 1/1 PASS",
        "manifest_emitted_by": "tools/parity/run.py",
        "inputs": [
            {"path": "in.c", "sha256": hashlib.sha256(src.read_bytes()).hexdigest()}
        ],
    }
    block["run_signature"] = signing.sign(key, block)
    return tmp_path, key, block


def test_artifact_under_docs_is_green(tmp_path: Path) -> None:
    root, key, block = build(tmp_path, "docs/status.md")
    assert evidence.evaluate(block, root, key, SCHEMA).verdict == "GREEN"


def test_artifact_outside_docs_is_red(tmp_path: Path) -> None:
    """A capture dump in build/ must never be cited as an artifact."""
    root, key, block = build(tmp_path, "build/vram_dump.md")
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("outside docs/" in r for r in result.reasons)


def test_oversized_artifact_is_red(tmp_path: Path) -> None:
    root, key, block = build(tmp_path, "docs/huge.md", size=1_100_000)
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("exceeds" in r for r in result.reasons)
