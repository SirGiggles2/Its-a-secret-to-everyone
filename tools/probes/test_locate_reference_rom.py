"""Tests for locate_reference_rom.py."""

import hashlib
import os
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))
from locate_reference_rom import resolve_rom, RomNotFoundError, RomHashMismatchError


def test_resolves_via_env_var(tmp_path: Path, monkeypatch) -> None:
    fake = tmp_path / "rom.nes"
    fake.write_bytes(b"hello")
    expected = hashlib.sha256(b"hello").hexdigest()
    monkeypatch.setenv("ZELDA_NES_ROM", str(fake))
    out = resolve_rom(expected_sha256=expected)
    assert out == fake


def test_raises_on_missing(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setenv("ZELDA_NES_ROM", str(tmp_path / "no_such.nes"))
    with pytest.raises(RomNotFoundError):
        resolve_rom(expected_sha256="0" * 64)


def test_raises_on_hash_mismatch(tmp_path: Path, monkeypatch) -> None:
    fake = tmp_path / "rom.nes"
    fake.write_bytes(b"hello")
    monkeypatch.setenv("ZELDA_NES_ROM", str(fake))
    with pytest.raises(RomHashMismatchError):
        resolve_rom(expected_sha256="0" * 64)
