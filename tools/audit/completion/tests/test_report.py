from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools" / "audit" / "completion"))

import collect
import report


def tracker(tmp_path: Path) -> dict:
    (tmp_path / "docs" / "audit" / "systems").mkdir(parents=True)
    return collect.build(tmp_path)


def test_reports_zero_percent_when_all_red(tmp_path: Path) -> None:
    text = report.render(tracker(tmp_path))
    assert "0 / 80" in text


def test_lists_every_system(tmp_path: Path) -> None:
    text = report.render(tracker(tmp_path))
    for system in ("frontend", "dungeons", "builder"):
        assert system in text


def test_na_counted_separately(tmp_path: Path) -> None:
    t = tracker(tmp_path)
    t["cells"][0]["verdict"] = "N/A"
    text = report.render(t)
    assert "N/A" in text
    assert "1 / 80" in text


def test_drift_section_present_when_drifted(tmp_path: Path) -> None:
    t = tracker(tmp_path)
    t["cells"][0]["drift"] = ["data/rooms/dungeons.c"]
    assert "data/rooms/dungeons.c" in report.render(t)
