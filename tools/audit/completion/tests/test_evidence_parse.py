from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools" / "audit" / "completion"))

import evidence

DOC = """# System audit — dungeons

## Axis verdicts

```yaml evidence
- system: dungeons
  axis: DATA
  verdict: GREEN
  artifact: docs/parity/dungeon_status.md
```

Some prose that must be ignored.

```python
print("not an evidence block")
```

```yaml evidence
- system: dungeons
  axis: CODE
  verdict: RED
```
"""


def test_parses_both_blocks(tmp_path: Path) -> None:
    p = tmp_path / "dungeons.md"
    p.write_text(DOC, encoding="utf-8")
    blocks = evidence.parse_blocks(p)
    assert len(blocks) == 2
    assert blocks[0]["axis"] == "DATA"
    assert blocks[1]["axis"] == "CODE"


def test_ignores_non_evidence_fences(tmp_path: Path) -> None:
    p = tmp_path / "dungeons.md"
    p.write_text(DOC, encoding="utf-8")
    assert all(b["system"] == "dungeons" for b in evidence.parse_blocks(p))


def test_malformed_yaml_raises(tmp_path: Path) -> None:
    p = tmp_path / "bad.md"
    p.write_text("```yaml evidence\n  : : nope\n```\n", encoding="utf-8")
    try:
        evidence.parse_blocks(p)
    except evidence.MalformedEvidence as exc:
        assert "bad.md" in str(exc)
    else:
        raise AssertionError("expected MalformedEvidence")


def test_no_blocks_returns_empty(tmp_path: Path) -> None:
    p = tmp_path / "empty.md"
    p.write_text("# nothing here\n", encoding="utf-8")
    assert evidence.parse_blocks(p) == []
