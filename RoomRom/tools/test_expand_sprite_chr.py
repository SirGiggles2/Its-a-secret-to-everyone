"""Test that expand_sprite_chr.py produces the expected pixel-biased output."""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_expand_sprite_chr_runs():
    result = subprocess.run(
        [sys.executable, str(ROOT / "RoomRom" / "tools" / "expand_sprite_chr.py")],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, f"stdout: {result.stdout}\nstderr: {result.stderr}"
    out_h = ROOT / "RoomRom" / "src" / "expanded_sprite_chr.h"
    out_c = ROOT / "RoomRom" / "src" / "expanded_sprite_chr.c"
    assert out_h.exists(), f"missing {out_h}"
    assert out_c.exists(), f"missing {out_c}"


def test_pixel_bias_rule_for_subpal_1():
    """Source pixel value 1 with sub_pal=1 -> output 1*4 + 1 = 5."""
    from importlib import import_module
    sys.path.insert(0, str(ROOT / "RoomRom" / "tools"))
    mod = import_module("expand_sprite_chr")
    biased = mod.bias_byte(0x12, 1)  # high nibble 1 -> 5, low nibble 2 -> 6
    assert biased == 0x56, f"expected 0x56, got 0x{biased:02X}"


def test_pixel_bias_rule_zero_stays_zero():
    """Source pixel value 0 -> output 0 for any sub_pal."""
    from importlib import import_module
    sys.path.insert(0, str(ROOT / "RoomRom" / "tools"))
    mod = import_module("expand_sprite_chr")
    for s in range(4):
        assert mod.bias_byte(0x03, s) == ((s * 4 + 3) & 0x0F), f"sub_pal={s}"
        assert mod.bias_byte(0x30, s) == (((s * 4 + 3) << 4) & 0xF0), f"sub_pal={s}"
        assert mod.bias_byte(0x00, s) == 0x00


if __name__ == "__main__":
    test_pixel_bias_rule_zero_stays_zero()
    test_pixel_bias_rule_for_subpal_1()
    test_expand_sprite_chr_runs()
    print("OK")
