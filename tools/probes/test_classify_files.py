"""Tests for classify_files.py."""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))
from classify_files import classify


@pytest.mark.parametrize("rel,expected", [
    ("src/enemy_runtime.c",                "owned_c"),
    ("src/enemy_walker_runtime.c",         "owned_c"),
    ("src/intro_main.c",                   "owned_c_frontend"),
    ("src/fs_main.c",                      "owned_c_frontend"),
    ("src/gen/intro_title_bg_chr.c",       "generated_data"),
    ("src/gen/fs_palette.c",               "generated_data"),
    ("src/gen/z_07.c",                     "transpile_adapter"),
    ("src/zelda_translated/z_07.asm",      "transpiled_asm"),
    ("src/nes_io.asm",                     "shim_asm"),
    ("src/c_shims.asm",                    "shim_asm"),
    ("src/genesis_shell.asm",              "platform_asm"),
    ("src/audio_driver.asm",               "platform_asm"),
    ("src/c_move_object.c",                "compat_wrapper"),
    ("src/c_wanderer.c",                   "compat_wrapper"),
    ("src/genesis_shell.asm.bak",          "cruft"),
    ("src/nes_io - Copy.txt",              "cruft"),
])
def test_classification(rel: str, expected: str) -> None:
    assert classify(rel) == expected
