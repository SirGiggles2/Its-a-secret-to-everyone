from __future__ import annotations

from pathlib import Path
import sys

import yaml

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools" / "audit" / "completion"))

import emit
import evidence
import signing


def test_recorder_discovers_reads(tmp_path: Path) -> None:
    src = tmp_path / "a.c"
    src.write_text("int a;\n", encoding="utf-8")
    rec = emit.EvidenceRecorder(root=tmp_path, key_path=tmp_path / ".k")
    rec.read(src)
    assert [i["path"] for i in rec.inputs] == ["a.c"]


def test_recorder_dedupes(tmp_path: Path) -> None:
    src = tmp_path / "a.c"
    src.write_text("int a;\n", encoding="utf-8")
    rec = emit.EvidenceRecorder(root=tmp_path, key_path=tmp_path / ".k")
    rec.read(src)
    rec.read(src)
    assert len(rec.inputs) == 1


def test_emitted_block_verifies(tmp_path: Path) -> None:
    (tmp_path / "docs").mkdir()
    art = tmp_path / "docs" / "s.md"
    art.write_text("Total 1/1 PASS\n", encoding="utf-8")
    src = tmp_path / "a.c"
    src.write_text("int a;\n", encoding="utf-8")

    rec = emit.EvidenceRecorder(root=tmp_path, key_path=tmp_path / ".k")
    rec.read(src)
    text = rec.emit(
        system="dungeons",
        axis="DATA",
        artifact=art,
        verdict_line="Total 1/1 PASS",
        command="python run.py",
        emitted_by="tools/parity/run.py",
    )

    block = yaml.safe_load(text.split("```yaml evidence")[1].split("```")[0])[0]
    key = signing.load_or_create_key(tmp_path / ".k")
    schema = {"artifact_root": "docs/", "max_artifact_bytes": 1048576, "na_allowlist": []}
    assert evidence.evaluate(block, tmp_path, key, schema).verdict == "GREEN"


def test_awkward_verdict_line_round_trips(tmp_path: Path) -> None:
    """Colons, quotes and leading % must survive the fence.

    Real verdict lines look like "dungeons: 171/171 PASS" — hand-formatted
    YAML would corrupt that into a nested mapping.
    """
    (tmp_path / "docs").mkdir()
    art = tmp_path / "docs" / "s.md"
    awkward = "dungeons: 171/171 PASS — 0 divergences, \"byte-exact\""
    art.write_text(f"{awkward}\n", encoding="utf-8")
    src = tmp_path / "a.c"
    src.write_text("int a;\n", encoding="utf-8")

    rec = emit.EvidenceRecorder(root=tmp_path, key_path=tmp_path / ".k")
    rec.read(src)
    text = rec.emit(
        system="dungeons",
        axis="DATA",
        artifact=art,
        verdict_line=awkward,
        command="python run.py --uw",
        emitted_by="tools/parity/run.py",
    )

    block = yaml.safe_load(text.split("```yaml evidence")[1].rsplit("```", 1)[0])[0]
    assert block["verdict_line"] == awkward
    key = signing.load_or_create_key(tmp_path / ".k")
    schema = {"artifact_root": "docs/", "max_artifact_bytes": 1048576, "na_allowlist": []}
    assert evidence.evaluate(block, tmp_path, key, schema).verdict == "GREEN"


def test_emit_refuses_absent_verdict_line(tmp_path: Path) -> None:
    (tmp_path / "docs").mkdir()
    art = tmp_path / "docs" / "s.md"
    art.write_text("nothing matching\n", encoding="utf-8")
    rec = emit.EvidenceRecorder(root=tmp_path, key_path=tmp_path / ".k")
    rec.read(art)
    try:
        rec.emit(
            system="dungeons",
            axis="DATA",
            artifact=art,
            verdict_line="Total 1/1 PASS",
            command="python run.py",
            emitted_by="tools/parity/run.py",
        )
    except ValueError as exc:
        assert "verdict_line" in str(exc)
    else:
        raise AssertionError("expected ValueError")
