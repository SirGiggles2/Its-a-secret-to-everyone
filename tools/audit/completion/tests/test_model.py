from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools" / "audit" / "completion"))

import model


def test_sixteen_systems() -> None:
    assert len(model.SYSTEMS) == 16
    assert model.SYSTEMS[0] == "frontend"
    assert "dungeons" in model.SYSTEMS
    assert "builder" in model.SYSTEMS


def test_five_axes() -> None:
    assert model.AXES == ("DATA", "BEHAVIOR", "PLAYABLE", "CODE", "LEGAL")


def test_grid_is_eighty_cells() -> None:
    cells = model.all_cells()
    assert len(cells) == 80
    assert len(set(cells)) == 80


def test_grid_order_is_stable() -> None:
    assert model.all_cells() == model.all_cells()
    assert model.all_cells()[0] == ("frontend", "DATA")
