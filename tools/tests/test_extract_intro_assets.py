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
