"""Tests for lint_legacy_symbols.py."""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))
from lint_legacy_symbols import lint_text


def test_clean_text_returns_no_findings() -> None:
    findings = lint_text("path.c", "void foo(void) { return; }\n")
    assert findings == []


def test_ppu_caller_is_flagged() -> None:
    findings = lint_text("src/foo.c", "  jsr _ppu_write_2006\n")
    assert len(findings) == 1
    f = findings[0]
    assert f.symbol == "_ppu_write_2006"
    assert f.lineno == 1
    assert f.path == "src/foo.c"


def test_z07_caller_is_flagged() -> None:
    findings = lint_text("src/c.c", "z07_anim_advance_and_fetch(0, slot);\n")
    assert len(findings) == 1
    assert findings[0].symbol == "z07_anim_advance_and_fetch"


def test_legacy_bridge_is_exempt() -> None:
    findings = lint_text(
        "src/abi/legacy_bridge.h",
        "extern void z07_anim_advance_and_fetch(unsigned, unsigned);\n",
    )
    assert findings == []


def test_zelda_translated_dir_is_exempt() -> None:
    findings = lint_text(
        "src/zelda_translated/z_07.asm",
        "  jsr _ppu_write_2006\n",
    )
    assert findings == []
