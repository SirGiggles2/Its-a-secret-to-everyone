#!/usr/bin/env python3
"""Phase J Step 2 (2026-05-18 VRAM cleanup): emit sparse BG atlas.

Reads:
  data/chr/common.c              -> common_chr[7616]
  data/chr/overworld_bg.c        -> overworld_bg_chr[4160]
  data/chr/underworld_bg.c       -> underworld_bg_chr[4160]
  RoomRom/src/redux_overworld_bg.c -> redux_overworld_bg_chr[4160]
  + audit_per_tile_subpal.py (per-tile (tile_id, sub_pal) usage)

Emits:
  RoomRom/src/bg_sparse_chr.c
  RoomRom/src/bg_sparse_chr.h

Each (tile_id, sub_pal) combo USED by any UW or OW room produces ONE
Genesis tile in the flat atlas (pixel-bias encoded per current rule).
LUT maps NES (tile_id, sub_pal) -> sparse tile slot; 0xFFFF sentinel
for unused combos.

3 variants emitted:
  bg_sparse_chr_orig_ow  — common + overworld_bg
  bg_sparse_chr_orig_uw  — common + underworld_bg
  bg_sparse_chr_redux_ow — common + redux_overworld_bg

Per §36.1 MF1 decision: variant-specific atlases share the same LUT
(tile_id -> slot mapping is universal); content differs per scene
context. Upload path picks which variant blob to upload at scene init.

Legacy expanded_bg_chr.{c,h} stays in place. Renderer switch is
Phase J Step 3 (not this commit).
"""
from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

# Defer import of audit until after sys.path setup
from tools.probes.audit_per_tile_subpal import (  # noqa: E402
    parse_uw_blob, collect_uw_per_tile_subpals,
    parse_ow_blob, collect_ow_per_tile_subpals,
)

ROOMROM = ROOT / "RoomRom"
OUT_C = ROOMROM / "src" / "bg_sparse_chr.c"
OUT_H = ROOMROM / "src" / "bg_sparse_chr.h"

BYTES_PER_TILE = 32

# Source array byte offsets for NES tile ranges (per ow_render.c upload).
# common_chr structure (7616 B = 238 tiles):
#   tiles 0x00..0x6F  -> common_chr bytes 0..3583 (BG section, 112 tiles)
#   tiles 0x70..0xDF  -> common_chr 3584..7167 (sprite section, 112 tiles)
#   tiles 0xF2..0xFF  -> common_chr 7168..7615 (misc section, 14 tiles)
# overworld_bg_chr / underworld_bg_chr / redux_overworld_bg_chr:
#   tiles 0x70..0xF1  -> bytes (tile_id - 0x70) * 32 (130 tiles, 4160 B)
COMMON_BG_END  = 0x70      # tiles below this come from common_chr at tile_id*32
COMMON_MISC_START = 0xF2   # tiles >= this come from common_chr misc section
COMMON_MISC_BYTE_OFFSET = 7168
SCENE_BG_START = 0x70
SCENE_BG_END   = 0xF2      # exclusive: 0x70..0xF1 = scene-specific
SCENE_BG_BYTES = 4160      # 130 tiles * 32


def fail(msg):
    print(f"gen_bg_sparse: FAIL: {msg}", file=sys.stderr)
    sys.exit(1)


def parse_array(text, name):
    pat = re.compile(
        r"const\s+unsigned\s+char\s+" + re.escape(name) +
        r"\s*\[\s*(\d+)\s*\]\s*=\s*\{([^}]*)\}",
        re.MULTILINE | re.DOTALL,
    )
    m = pat.search(text)
    if not m:
        return None
    size = int(m.group(1))
    body = m.group(2)
    bytes_out = [int(t.group(1), 16) for t in re.finditer(r"0x([0-9A-Fa-f]{1,2})", body)]
    if len(bytes_out) != size:
        fail(f"{name}: declared {size} != parsed {len(bytes_out)}")
    return bytes(bytes_out)


def load_source(rel_path, name):
    path = ROOT / rel_path
    if not path.exists():
        fail(f"{rel_path}: not found")
    text = path.read_text(encoding="utf-8")
    data = parse_array(text, name)
    if data is None:
        fail(f"{rel_path}: array `{name}` not found")
    return data


def bias_byte(b, sub_pal):
    """Mirror expand_bg_chr.py:86-91 bias rule (out = 0 if in==0 else s*4+in)."""
    hi = (b >> 4) & 0x0F
    lo = b & 0x0F
    hi_out = 0 if hi == 0 else (sub_pal * 4 + hi)
    lo_out = 0 if lo == 0 else (sub_pal * 4 + lo)
    return ((hi_out & 0x0F) << 4) | (lo_out & 0x0F)


def get_nes_tile_bytes(tile_id, common_chr, scene_bg_chr):
    """Return 32 raw NES bytes for a given NES BG tile_id, picking source per range."""
    if tile_id < COMMON_BG_END:
        # 0x00..0x6F from common_chr BG section
        off = tile_id * BYTES_PER_TILE
        return common_chr[off:off + BYTES_PER_TILE]
    if tile_id >= COMMON_MISC_START:
        # 0xF2..0xFF from common_chr misc section
        off = COMMON_MISC_BYTE_OFFSET + (tile_id - COMMON_MISC_START) * BYTES_PER_TILE
        return common_chr[off:off + BYTES_PER_TILE]
    # 0x70..0xF1 from scene-specific BG
    off = (tile_id - SCENE_BG_START) * BYTES_PER_TILE
    return scene_bg_chr[off:off + BYTES_PER_TILE]


def emit_sparse_blob(per_tile_usage, common_chr, scene_bg_chr, name_for_log):
    """Returns (flat_bytes, lut_256x4). LUT[tile_id][sub_pal] = slot_index
    (0..N-1) into the flat tile array; 0xFFFF sentinel if combo unused."""
    lut = [[0xFFFF] * 4 for _ in range(256)]
    flat = bytearray()
    slot = 0
    for tile_id in sorted(per_tile_usage.keys()):
        for sub_pal in sorted(per_tile_usage[tile_id]):
            raw = get_nes_tile_bytes(tile_id, common_chr, scene_bg_chr)
            if len(raw) != BYTES_PER_TILE:
                fail(f"{name_for_log}: tile 0x{tile_id:02X} short: {len(raw)} B")
            for b in raw:
                flat.append(bias_byte(b, sub_pal))
            if slot >= 0xFFFF:
                fail(f"{name_for_log}: slot overflow at tile 0x{tile_id:02X} sub-pal {sub_pal}")
            lut[tile_id][sub_pal] = slot
            slot += 1
    return bytes(flat), lut


def emit_c_array(f, name, data):
    f.write(f"const unsigned char {name}[{len(data)}] __attribute__((aligned(4))) = {{\n")
    cols = 16
    for i in range(0, len(data), cols):
        chunk = data[i:i + cols]
        f.write("    " + ", ".join(f"0x{b:02X}" for b in chunk))
        if i + cols < len(data):
            f.write(",")
        f.write("\n")
    f.write("};\n\n")


def emit_lut(f, name, lut):
    f.write(f"const unsigned short {name}[256][4] __attribute__((aligned(2))) = {{\n")
    for tile_id in range(256):
        entries = ", ".join(f"0x{v:04X}" for v in lut[tile_id])
        comma = "," if tile_id < 255 else ""
        f.write(f"    {{ {entries} }}{comma}  /* tile 0x{tile_id:02X} */\n")
    f.write("};\n\n")


def main():
    # Load source arrays
    common_chr = load_source("data/chr/common.c", "common_chr")
    overworld_bg_chr = load_source("data/chr/overworld_bg.c", "overworld_bg_chr")
    underworld_bg_chr = load_source("data/chr/underworld_bg.c", "underworld_bg_chr")
    redux_overworld_bg_chr = load_source(
        "RoomRom/src/redux_overworld_bg.c", "redux_overworld_bg_chr")

    # Run audits (deterministic per Phase J §36.1 MF4)
    uw_rooms = parse_uw_blob()
    ow_bytes = parse_ow_blob()
    per_tile_uw = collect_uw_per_tile_subpals(uw_rooms)
    per_tile_ow = collect_ow_per_tile_subpals(ow_bytes)

    # Combined usage (universal LUT spans UW + OW union)
    combined = defaultdict(set)
    for d in (per_tile_uw, per_tile_ow):
        for tid, sps in d.items():
            combined[tid].update(sps)

    # Emit per-variant blobs against COMBINED usage (so LUT is universal)
    orig_ow_blob, orig_ow_lut = emit_sparse_blob(
        combined, common_chr, overworld_bg_chr, "orig_ow")
    orig_uw_blob, orig_uw_lut = emit_sparse_blob(
        combined, common_chr, underworld_bg_chr, "orig_uw")
    redux_ow_blob, redux_ow_lut = emit_sparse_blob(
        combined, common_chr, redux_overworld_bg_chr, "redux_ow")

    # All three LUTs should be IDENTICAL (slot allocation is variant-invariant)
    assert orig_ow_lut == orig_uw_lut == redux_ow_lut, \
        "LUT divergence — variant-invariant slot allocation expected"

    n_tiles = sum(len(s) for s in combined.values())
    bytes_per_variant = n_tiles * BYTES_PER_TILE
    print(f"  combined unique (tile_id, sub_pal) combos: {n_tiles}")
    print(f"  per-variant blob: {bytes_per_variant} bytes ({n_tiles} tiles)")
    print(f"  ROM total: 3 variants x {bytes_per_variant} B + 1 LUT (256x4x2 = 2048 B) "
          f"= {3 * bytes_per_variant + 2048} bytes")
    legacy_bytes = 3 * 7616 * 4 + 4 * 4160 * 4 + 1024 * 4  # rough estimate
    print(f"  (legacy x4 estimated: ~{legacy_bytes // 1024} KB)")

    # Emit header
    with OUT_H.open("w", encoding="utf-8") as f:
        f.write("/* Auto-generated by RoomRom/tools/gen_bg_sparse.py. Do not edit. */\n")
        f.write("#ifndef ROOMROM_BG_SPARSE_CHR_H\n")
        f.write("#define ROOMROM_BG_SPARSE_CHR_H\n\n")
        f.write("/* Phase J sparse BG atlas: per-variant flat tile array indexed by\n"
                " * bg_sparse_tile_lut[nes_tile_id][nes_sub_pal] -> slot index (0..N-1).\n"
                " * Sentinel 0xFFFF = (tile_id, sub_pal) never referenced by any room.\n"
                " * Each variant's blob is bias-encoded (out=(in==0)?0:(s*4+in)) so the\n"
                " * tile renders correctly via PAL0 pixel-bias when looked up at its slot.\n"
                " *\n"
                " * NOTE Phase J Step 2: data emitted; legacy expanded_bg_chr.{c,h} also\n"
                " * in tree. Renderer switch is Step 3 (not this commit). Atlas + LUT\n"
                " * are ready but not yet wired. */\n\n")
        f.write(f"#define BG_SPARSE_TILE_COUNT      {n_tiles}u\n")
        f.write(f"#define BG_SPARSE_BLOB_BYTES      {bytes_per_variant}u\n")
        f.write("\n")
        f.write(f"extern const unsigned char  bg_sparse_chr_orig_ow [{bytes_per_variant}];\n")
        f.write(f"extern const unsigned char  bg_sparse_chr_orig_uw [{bytes_per_variant}];\n")
        f.write(f"extern const unsigned char  bg_sparse_chr_redux_ow[{bytes_per_variant}];\n")
        f.write("extern const unsigned short bg_sparse_tile_lut[256][4];\n")
        f.write("\n#endif /* ROOMROM_BG_SPARSE_CHR_H */\n")

    # Emit source
    with OUT_C.open("w", encoding="utf-8") as f:
        f.write("/* Auto-generated by RoomRom/tools/gen_bg_sparse.py. Do not edit. */\n")
        f.write('#include "bg_sparse_chr.h"\n\n')
        emit_c_array(f, "bg_sparse_chr_orig_ow", orig_ow_blob)
        emit_c_array(f, "bg_sparse_chr_orig_uw", orig_uw_blob)
        emit_c_array(f, "bg_sparse_chr_redux_ow", redux_ow_blob)
        emit_lut(f, "bg_sparse_tile_lut", orig_ow_lut)

    print(f"wrote {OUT_H.relative_to(ROOT)}")
    print(f"wrote {OUT_C.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
