from __future__ import annotations

import hashlib
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools" / "audit" / "completion"))

import collect
import evidence
import model
import signing


def test_empty_repo_is_all_red(tmp_path: Path) -> None:
    (tmp_path / "docs" / "audit" / "systems").mkdir(parents=True)
    tracker = collect.build(tmp_path)
    assert len(tracker["cells"]) == 80
    assert all(c["verdict"] == "RED" for c in tracker["cells"])


def test_missing_system_file_names_the_gap(tmp_path: Path) -> None:
    (tmp_path / "docs" / "audit" / "systems").mkdir(parents=True)
    tracker = collect.build(tmp_path)
    cell = next(c for c in tracker["cells"] if c["system"] == "dungeons")
    assert any("audit not yet run" in r for r in cell["reasons"])


def test_cells_are_in_stable_order(tmp_path: Path) -> None:
    (tmp_path / "docs" / "audit" / "systems").mkdir(parents=True)
    tracker = collect.build(tmp_path)
    got = [(c["system"], c["axis"]) for c in tracker["cells"]]
    assert got == model.all_cells()


def test_two_runs_are_byte_identical(tmp_path: Path) -> None:
    """Determinism: no wall-clock or environment fields in the tracker."""
    (tmp_path / "docs" / "audit" / "systems").mkdir(parents=True)
    first = collect.serialize(collect.build(tmp_path))
    second = collect.serialize(collect.build(tmp_path))
    assert first == second


def test_tracker_carries_no_timestamp(tmp_path: Path) -> None:
    (tmp_path / "docs" / "audit" / "systems").mkdir(parents=True)
    blob = collect.serialize(collect.build(tmp_path))
    assert "generated_at" not in blob


# ── Contradiction scoping (finding B) ────────────────────────────────────

def _write_system(root: Path, system: str, blocks: str) -> None:
    d = root / "docs" / "audit" / "systems"
    d.mkdir(parents=True, exist_ok=True)
    (d / f"{system}.md").write_text(blocks, encoding="utf-8")


def _shared_artifact(root: Path) -> Path:
    (root / "docs").mkdir(parents=True, exist_ok=True)
    art = root / "docs" / "matrix.md"
    art.write_text("dungeons: GREEN 12/12\ncaves: GREEN 20/20\n", encoding="utf-8")
    return art


def _block(root: Path, key: bytes, system: str, verdict_line: str) -> str:
    import yaml

    art = root / "docs" / "matrix.md"
    src = root / "shared.py"
    if not src.exists():
        src.write_text("x = 1\n", encoding="utf-8")
    b = {
        "system": system,
        "axis": "CODE",
        "verdict": "GREEN",
        "artifact": "docs/matrix.md",
        "artifact_sha256": hashlib.sha256(art.read_bytes()).hexdigest(),
        "command": "python tools/run_regression_matrix.py",
        "verdict_line": verdict_line,
        "manifest_emitted_by": "tools/run_regression_matrix.py",
        "inputs": [
            {"path": "shared.py", "sha256": hashlib.sha256(src.read_bytes()).hexdigest()}
        ],
    }
    b["run_signature"] = signing.sign(key, b)
    dumped = yaml.safe_dump([b], sort_keys=False, default_flow_style=False)
    return f"```yaml evidence\n{dumped}```\n"


def _key(root: Path) -> bytes:
    return signing.load_or_create_key(
        root / "tools" / "audit" / "completion" / ".evidence_key"
    )


def test_shared_artifact_across_systems_is_not_a_contradiction(tmp_path: Path) -> None:
    (tmp_path / "docs" / "audit" / "systems").mkdir(parents=True)
    _shared_artifact(tmp_path)
    key = _key(tmp_path)
    _write_system(
        tmp_path, "dungeons", _block(tmp_path, key, "dungeons", "dungeons: GREEN 12/12")
    )
    _write_system(
        tmp_path, "caves", _block(tmp_path, key, "caves", "caves: GREEN 20/20")
    )

    tracker = collect.build(tmp_path)
    verdicts = {
        (c["system"], c["axis"]): c
        for c in tracker["cells"]
        if c["axis"] == "CODE" and c["system"] in ("dungeons", "caves")
    }
    assert verdicts[("dungeons", "CODE")]["verdict"] == "GREEN", verdicts[
        ("dungeons", "CODE")
    ]["reasons"]
    assert verdicts[("caves", "CODE")]["verdict"] == "GREEN", verdicts[
        ("caves", "CODE")
    ]["reasons"]


def test_duplicate_system_axis_claim_raises(tmp_path: Path) -> None:
    (tmp_path / "docs" / "audit" / "systems").mkdir(parents=True)
    _shared_artifact(tmp_path)
    key = _key(tmp_path)
    doubled = _block(tmp_path, key, "dungeons", "dungeons: GREEN 12/12") * 2
    _write_system(tmp_path, "dungeons", doubled)
    try:
        collect.build(tmp_path)
    except evidence.MalformedEvidence as exc:
        assert "duplicate claim" in str(exc)
    else:
        raise AssertionError("expected MalformedEvidence")
