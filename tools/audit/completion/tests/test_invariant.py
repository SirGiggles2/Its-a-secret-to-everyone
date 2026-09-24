"""The one test that matters: no hand-authored file can mint GREEN.

This is the regression test for the defect that motivated the whole
design — tools/audit/primedirective/prime_refresh.py assigned phase
status positionally, so every phase before the active one defaulted to
"complete" with no evidence check whatsoever.
"""
from __future__ import annotations

import hashlib
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools" / "audit" / "completion"))

import collect
import model


FORGED = """```yaml evidence
- system: dungeons
  axis: DATA
  verdict: GREEN
  artifact: docs/status.md
  artifact_sha256: {sha}
  command: python tools/parity/cave_golden/run_full_diff.py --uw
  verdict_line: 'Total 171/171 PASS'
  manifest_emitted_by: tools/parity/cave_golden/run_full_diff.py
  run_signature: {sig}
  inputs:
    - path: rooms.c
      sha256: {src}
```
"""


def test_forged_evidence_cannot_produce_green(tmp_path: Path) -> None:
    (tmp_path / "docs" / "audit" / "systems").mkdir(parents=True)
    art = tmp_path / "docs" / "status.md"
    art.write_text("Total 171/171 PASS\n", encoding="utf-8")
    src = tmp_path / "rooms.c"
    src.write_text("int x;\n", encoding="utf-8")

    # Every field is internally consistent. The hashes are real. The
    # artifact genuinely contains the verdict line. Only the signature
    # is invented — and that alone must be enough to stop it.
    forged = FORGED.format(
        sha=hashlib.sha256(art.read_bytes()).hexdigest(),
        src=hashlib.sha256(src.read_bytes()).hexdigest(),
        sig="f" * 64,
    )
    (tmp_path / "docs" / "audit" / "systems" / "dungeons.md").write_text(
        forged, encoding="utf-8"
    )

    tracker = collect.build(tmp_path)
    cell = next(
        c
        for c in tracker["cells"]
        if c["system"] == "dungeons" and c["axis"] == "DATA"
    )
    assert cell["verdict"] == "RED"
    assert any("run_signature" in r for r in cell["reasons"])


def test_no_positional_inference(tmp_path: Path) -> None:
    """A GREEN cell must never make its neighbours GREEN."""
    (tmp_path / "docs" / "audit" / "systems").mkdir(parents=True)
    tracker = collect.build(tmp_path)
    assert len({c["verdict"] for c in tracker["cells"]}) == 1
    assert all(c["verdict"] == "RED" for c in tracker["cells"])


def test_every_cell_is_accounted_for(tmp_path: Path) -> None:
    (tmp_path / "docs" / "audit" / "systems").mkdir(parents=True)
    tracker = collect.build(tmp_path)
    assert {(c["system"], c["axis"]) for c in tracker["cells"]} == set(
        model.all_cells()
    )
