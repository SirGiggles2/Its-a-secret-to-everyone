import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
TOOL = REPO / "tools" / "extract_intro_assets.py"

def test_tool_runs_with_help():
    result = subprocess.run([sys.executable, str(TOOL), "--help"],
                            stdin=subprocess.DEVNULL,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True)
    assert result.returncode == 0
    assert "extract" in result.stdout.lower()

def test_tool_rejects_missing_ref_dir():
    result = subprocess.run([sys.executable, str(TOOL),
                             "--ref-dir", "/nonexistent/path/does/not/exist"],
                            stdin=subprocess.DEVNULL,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True)
    assert result.returncode != 0


# Tests for nes_tile_to_gen_tile pure function
from tools.extract_intro_assets import nes_tile_to_gen_tile

def test_nes_tile_to_gen_tile_all_zero():
    nes = bytes(16)  # 16 bytes NES tile, all zero
    gen = nes_tile_to_gen_tile(nes)
    assert len(gen) == 32
    assert gen == bytes(32)

def test_nes_tile_to_gen_tile_color_1():
    # NES tile where bitplane 0 = 0xFF (all pixels = color 1)
    nes = bytes([0xFF] * 8 + [0x00] * 8)
    gen = nes_tile_to_gen_tile(nes)
    assert len(gen) == 32
    # Genesis 4bpp: each pixel is a nibble; all pixels = 1 → every byte = 0x11
    assert gen == bytes([0x11] * 32)

def test_nes_tile_to_gen_tile_color_3():
    # NES tile where both bitplanes = 0xFF (all pixels = color 3)
    nes = bytes([0xFF] * 16)
    gen = nes_tile_to_gen_tile(nes)
    assert len(gen) == 32
    assert gen == bytes([0x33] * 32)


# Tests for nes_color_to_gen_cram pure function
from tools.extract_intro_assets import nes_color_to_gen_cram

def test_nes_black_to_gen():
    # NES $0F is black → Genesis $0000
    assert nes_color_to_gen_cram(0x0F) == 0x0000

def test_nes_white_to_gen():
    # NES $30 is white-ish → Genesis $0EEE (all channels max)
    v = nes_color_to_gen_cram(0x30)
    # each nibble >= 0xA (top two bins of the quantizer)
    assert (v & 0x000E) >= 0x000A
    assert ((v >> 4) & 0x000E) >= 0x000A
    assert ((v >> 8) & 0x000E) >= 0x000A

def test_nes_color_range():
    for i in range(64):
        v = nes_color_to_gen_cram(i)
        assert 0 <= v <= 0x0EEE
        assert (v & 0x0111) == 0  # low bit of each nibble zero (Gen format)

def test_emit_produces_font_and_art_chr(tmp_path):
    import subprocess, sys
    out_dir = tmp_path
    result = subprocess.run([
        sys.executable, str(TOOL),
        "--ref-dir", str(REPO / "reference" / "aldonunez" / "dat"),
        "--out-dir", str(out_dir),
        "--handoff-json", str(REPO / "docs" / "superpowers" / "captures" /
                              "2026-04-24-intro-handoff-state.json"),
        "--restore-chr",  str(REPO / "docs" / "superpowers" / "captures" /
                              "2026-04-24-intro-restore-chr.bin"),
        "--restore-cram", str(REPO / "docs" / "superpowers" / "captures" /
                              "2026-04-24-intro-restore-cram.bin"),
    ], stdin=subprocess.DEVNULL,
       stdout=subprocess.PIPE, stderr=subprocess.PIPE,
       text=True)
    assert result.returncode == 0, result.stderr
    font = (out_dir / "intro_font_chr.c").read_text()
    art = (out_dir / "intro_art_chr.c").read_text()
    assert "const unsigned char intro_font_chr" in font
    assert "const unsigned char intro_art_chr" in art
    assert len(font.splitlines()) > 20  # non-empty
