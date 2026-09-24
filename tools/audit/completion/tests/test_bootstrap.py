from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools" / "audit" / "completion"))

import model


def test_every_system_has_an_audit_file() -> None:
    for system in model.SYSTEMS:
        path = ROOT / "docs" / "audit" / "systems" / f"{system}.md"
        assert path.is_file(), f"missing audit file for {system}"


def test_audit_files_have_required_sections() -> None:
    for system in model.SYSTEMS:
        text = (ROOT / "docs" / "audit" / "systems" / f"{system}.md").read_text(
            encoding="utf-8"
        )
        for heading in ("## Scope", "## Axis verdicts", "## Gap list", "## Tolerance"):
            assert heading in text, f"{system}.md missing {heading}"
