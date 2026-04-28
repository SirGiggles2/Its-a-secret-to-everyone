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
    ("src/zelda_translated/z_07 - Copy.txt", "cruft"),
    # Live data includes pulled in by src/audio_driver.asm and the
    # extraction pipeline — must NOT be classified as cruft.
    ("src/data/music_blob.inc",            "extracted_data_inc"),
    ("src/data/music_blob.dat",            "extracted_data_inc"),
    ("src/data/dmc_samples.inc",           "extracted_data_inc"),
    ("src/data/dmc_samples.bin",           "extracted_data_inc"),
    ("src/data/songs.inc",                 "extracted_data_inc"),
    ("src/data/tiles_overworld_bg.inc",    "extracted_data_inc"),
    # Live build manifests emitted by tools/extract_*_assets.py.
    ("src/gen/intro_asset_hashes.txt",     "asset_manifest"),
    ("src/gen/fs_asset_hashes.txt",        "asset_manifest"),
])
def test_classification(rel: str, expected: str) -> None:
    assert classify(rel) == expected
