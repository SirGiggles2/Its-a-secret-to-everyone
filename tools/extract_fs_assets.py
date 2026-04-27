"""Extract Zelda Redux File Select assets from Redux NES reference data + nametable dump.

Emits src/gen/fs_static_tilemap.c, fs_palette.c, fs_font_chr.c,
fs_link_sprite_chr.c, fs_heart_cursor_chr.c, fs_border_chr.c.
Writes src/gen/fs_asset_hashes.txt with SHA256 of every output.

CHR source: reference/aldonunez/dat/CommonBackgroundPatterns.dat (112 tiles)
            + DemoBackgroundPatterns.dat (130 tiles) = 242 BG tiles (0x00-0xF1)
            + CommonSpritePatterns.dat (112 tiles)
            + DemoSpritePatterns.dat (144 tiles) = 256 sprite tiles (0x00-0xFF)

These .dat files contain actual NES 2bpp CHR pixel data, not PRG-ROM code.
The Zelda Redux ROM is CHR-RAM; the game transfers these patterns to PPU at runtime.
"""
from __future__ import annotations

import hashlib
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
REF_DIR = REPO / "reference" / "aldonunez" / "dat"
NT_DUMP = REPO / "tools" / "file_select_test" / "ref" / "fs_nt.bin"
OUT_DIR = REPO / "src" / "gen"

# Import shared helpers from extract_intro_assets.py (same repo, same tools/ dir).
sys.path.insert(0, str(REPO / "tools"))
from extract_intro_assets import nes_color_to_gen_cram, nes_tile_to_gen_tile


# ---------------------------------------------------------------------------
# CHR data loaders (BG and sprite pattern tables from reference .dat files)
# ---------------------------------------------------------------------------

def _load_bg_chr() -> bytes:
    """Load CommonBackgroundPatterns + DemoBackgroundPatterns (242 tiles = 0x00-0xF1)."""
    common = (REF_DIR / "CommonBackgroundPatterns.dat").read_bytes()
    demo   = (REF_DIR / "DemoBackgroundPatterns.dat").read_bytes()
    return common + demo


def _load_sprite_chr() -> bytes:
    """Load CommonSpritePatterns + DemoSpritePatterns (256 tiles = 0x00-0xFF)."""
    common = (REF_DIR / "CommonSpritePatterns.dat").read_bytes()
    demo   = (REF_DIR / "DemoSpritePatterns.dat").read_bytes()
    return common + demo


def _read_bg_tile(tile_idx: int, bg_chr: bytes) -> bytes:
    """Return the 16-byte NES tile for BG tile index tile_idx."""
    off = tile_idx * 16
    if off + 16 > len(bg_chr):
        raise IndexError(
            f"BG tile 0x{tile_idx:02X} out of range (CHR has {len(bg_chr)//16} tiles)"
        )
    return bg_chr[off:off + 16]


def _read_sprite_tile(tile_idx: int, sprite_chr: bytes) -> bytes:
    """Return the 16-byte NES tile for sprite tile index tile_idx."""
    off = tile_idx * 16
    if off + 16 > len(sprite_chr):
        raise IndexError(
            f"Sprite tile 0x{tile_idx:02X} out of range (CHR has {len(sprite_chr)//16} tiles)"
        )
    return sprite_chr[off:off + 16]


# ---------------------------------------------------------------------------
# v1.1 — Palette
# ---------------------------------------------------------------------------

def emit_palette() -> None:
    """Emit src/gen/fs_palette.c with Link bright + dim palettes.

    Source: Zelda1-Redux/src/code/menus/file_select.asm lines 75-78
        $0F,$29,$27,$17    ; Black, green, beige, brown  (slot 1 saved / green Link)
        $0F,$22,$27,$17    ; Black, blue, beige, brown   (slot 2 saved / blue Link)
        $0F,$16,$27,$17    ; Black, red, beige, brown    (slot 3 saved / red Link)
        (dim variant TBD — placeholder until NES capture validates it)
    """
    LINK_PALETTES = [
        (0x0F, 0x29, 0x27, 0x17),  # slot 1 saved (green)
        (0x0F, 0x22, 0x27, 0x17),  # slot 2 saved (blue)
        (0x0F, 0x16, 0x27, 0x17),  # slot 3 saved (red)
        (0x0F, 0x00, 0x10, 0x10),  # dim / empty slot (placeholder — tune after NES capture)
    ]
    out = []
    out.append("/* AUTO-GENERATED — see tools/extract_fs_assets.py */")
    out.append("/* Source: Zelda1-Redux/src/code/menus/file_select.asm:75-78 */")
    out.append("#include <stdint.h>")
    out.append("/* fs_link_palettes[4][4]: index 0=slot1(green) 1=slot2(blue) 2=slot3(red) 3=dim */")
    out.append("const uint16_t fs_link_palettes[4][4] = {")
    for pal in LINK_PALETTES:
        cram = [nes_color_to_gen_cram(c) for c in pal]
        out.append("    { " + ", ".join(f"0x{w:04X}" for w in cram) + " },")
    out.append("};")
    (OUT_DIR / "fs_palette.c").write_text("\n".join(out) + "\n")
    print("[fs] emitted fs_palette.c")


# ---------------------------------------------------------------------------
# v1.1 — Static tilemap
# ---------------------------------------------------------------------------

def emit_static_tilemap() -> None:
    """Emit src/gen/fs_static_tilemap.c from the 1024-byte nametable dump.

    The dump is a raw 32x30=960-byte nametable + 64-byte attribute table.
    We emit only the first 960 bytes (tile indices); attribute data is excluded.
    Callers apply the Genesis CHR base offset at VDP upload time.
    """
    if not NT_DUMP.exists():
        sys.stderr.write(
            f"ERROR: nametable dump missing: {NT_DUMP}\n"
            "Run tools/file_select_test/dump_fs_nametable.lua in BizHawk first.\n"
        )
        sys.exit(1)
    raw = NT_DUMP.read_bytes()
    if len(raw) != 1024:
        sys.stderr.write(
            f"ERROR: expected 1024-byte NT dump, got {len(raw)} bytes\n"
        )
        sys.exit(1)
    out = []
    out.append("/* AUTO-GENERATED — see tools/extract_fs_assets.py */")
    out.append("/* Source: tools/file_select_test/ref/fs_nt.bin (BizHawk PPUNT capture) */")
    out.append("#include <stdint.h>")
    out.append("/* 30 rows x 32 cols = 960 tile bytes; attribute table (last 64) excluded.")
    out.append(" * Tile indices are raw NES BG PT indices; caller adds Genesis CHR base. */")
    out.append("const uint8_t fs_static_tilemap[960] = {")
    for row in range(30):
        line = "    " + ", ".join(f"0x{raw[row * 32 + col]:02X}" for col in range(32)) + ","
        out.append(line)
    out.append("};")
    (OUT_DIR / "fs_static_tilemap.c").write_text("\n".join(out) + "\n")
    print("[fs] emitted fs_static_tilemap.c")


# ---------------------------------------------------------------------------
# v1.2 — CHR extraction helpers
# ---------------------------------------------------------------------------

# CHR tile index constants documented from NES OAM/nametable evidence.
#
# Heart cursor: 0xF3 — locked by task v1.R8 (NES ROM at PRG addr 0xA589 / file 0xA599
#   in bank 2). Confirmed: sprite tile byte at OAM+1 for main-menu cursor sprite.
#
# Link sprite: tiles 0x08-0x0B confirmed from aldonunez/Z_02.asm Mode1_WriteLinkSprites.
#   NES 8x16 sprite mode: left column tile index $08 (top half=row $08, bot half=row $09),
#   right column tile index $0A (top half=row $0A, bot half=row $0B).
#   Mode1_WriteLinkSprites (Z_02.asm:2698-2700): LDA #$08→[$02]=left, LDA #$0A→[$03]=right.
#   These are sprite CHR tiles from CommonSpritePatterns.dat (tiles 0x00-0x6F).
#
# Font: BG tiles 0x00-0x09 = digits 0-9, 0x0A-0x23 = letters A-Z (Zelda 1 standard).
#   Space = 0x24. Wider range 0x00-0x63 covers all text glyphs in nametable.
#
# Border: tiles 0xD4-0xE1 + 0xED + 0xEE identified from nametable col 0/1/30/31 analysis.
#   These are all BG tiles (color_shift=0).

LINK_SPRITE_TILES  = [0x08, 0x09, 0x0A, 0x0B]  # NES OAM evidence: Mode1_WriteLinkSprites sets
                                                # left tile=$08, right tile=$0A; NES 8x16 sprite
                                                # mode means $08→rows $08/$09 (left col top/bot),
                                                # $0A→rows $0A/$0B (right col top/bot).
                                                # Source: aldonunez/Z_02.asm:2698-2700
HEART_CURSOR_TILE  = 0xF3                        # locked v1.R8
FONT_TILES_START   = 0x00
FONT_TILES_END     = 0x64   # exclusive; covers 0x00-0x63 (100 tiles)
BORDER_TILES       = [
    0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xDB,
    0xDC, 0xDD, 0xDE, 0xDF, 0xE0, 0xE1, 0xED, 0xEE,
]


def _emit_chr_array(
    tiles_nes: list[bytes],
    symbol: str,
    color_shift: int = 0,
) -> None:
    """Convert list of 16-byte NES tiles to Genesis 4bpp and write to src/gen/{symbol}.c."""
    out = []
    out.append("/* AUTO-GENERATED — see tools/extract_fs_assets.py */")
    out.append("#include <stdint.h>")
    n_tiles = len(tiles_nes)
    out.append(f"const uint8_t {symbol}[{n_tiles * 32}] = {{")
    for nes_tile in tiles_nes:
        gen_tile = nes_tile_to_gen_tile(nes_tile, color_shift=color_shift)
        out.append("    " + ", ".join(f"0x{b:02X}" for b in gen_tile) + ",")
    out.append("};")
    (OUT_DIR / f"{symbol}.c").write_text("\n".join(out) + "\n")
    print(f"[fs] emitted {symbol}.c  ({n_tiles} tiles)")


def emit_link_sprite_chr() -> None:
    """Emit src/gen/fs_link_sprite_chr.c from 4 sprite CHR tiles (NES OAM evidence).

    Tiles 0x08-0x0B: left-col top/bot + right-col top/bot for front-facing Link
    in 8x16 sprite mode (Mode1_WriteLinkSprites, aldonunez/Z_02.asm:2698).
    """
    sp = _load_sprite_chr()
    tiles = [_read_sprite_tile(ti, sp) for ti in LINK_SPRITE_TILES]
    _emit_chr_array(tiles, "fs_link_sprite_chr", color_shift=4)


def emit_heart_cursor_chr() -> None:
    """Emit src/gen/fs_heart_cursor_chr.c — 1 sprite tile (locked: 0xF3)."""
    sp = _load_sprite_chr()
    tiles = [_read_sprite_tile(HEART_CURSOR_TILE, sp)]
    _emit_chr_array(tiles, "fs_heart_cursor_chr", color_shift=4)


def emit_font_chr() -> None:
    """Emit src/gen/fs_font_chr.c — BG tiles 0x00-0x63 (digits, letters, glyphs).

    Tile layout:
      0x00-0x09  digits 0-9
      0x0A-0x23  letters A-Z (standard Zelda 1 encoding)
      0x24       space (blank)
      0x25-0x63  additional glyphs present in the FS nametable
    """
    bg = _load_bg_chr()
    tiles = [_read_bg_tile(ti, bg) for ti in range(FONT_TILES_START, FONT_TILES_END)]
    _emit_chr_array(tiles, "fs_font_chr", color_shift=0)


def emit_border_chr() -> None:
    """Emit src/gen/fs_border_chr.c — BG border/frame decoration tiles.

    Tile indices identified from nametable column 0/1/30/31 analysis:
      0xD4-0xE1  primary border pieces (corners + edges + vine decorations)
      0xED, 0xEE  additional border detail tiles
    """
    bg = _load_bg_chr()
    tiles = [_read_bg_tile(ti, bg) for ti in BORDER_TILES]
    _emit_chr_array(tiles, "fs_border_chr", color_shift=0)


def emit_chr_blocks() -> None:
    """Emit all four CHR block files for v1.2."""
    emit_link_sprite_chr()
    emit_heart_cursor_chr()
    emit_font_chr()
    emit_border_chr()


# ---------------------------------------------------------------------------
# Hash file
# ---------------------------------------------------------------------------

def hash_outputs() -> None:
    """Write src/gen/fs_asset_hashes.txt — SHA256 of every fs_*.c output."""
    entries = []
    for p in sorted(OUT_DIR.glob("fs_*.c")):
        digest = hashlib.sha256(p.read_bytes()).hexdigest()
        entries.append(f"{digest}  {p.name}")
    (OUT_DIR / "fs_asset_hashes.txt").write_text("\n".join(entries) + "\n")
    print(f"[fs] wrote fs_asset_hashes.txt  ({len(entries)} files hashed)")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # v1.1 — scaffold
    emit_palette()
    emit_static_tilemap()

    # v1.2 — CHR extraction
    emit_chr_blocks()

    hash_outputs()
    print(f"[fs] all assets emitted to {OUT_DIR}")
